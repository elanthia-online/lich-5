# frozen_string_literal: true

require 'tmpdir'
require_relative '../../lib/r4l5_contract_check'

RSpec.describe Lich::R4L5ContractCheck do
  let(:gemfile) { +"gem 'redis'\n" }
  let(:lockfile) do
    <<~LOCK
      GEM
        remote: https://rubygems.org/
        specs:
          redis (6.0.0)
            redis-client (= 0.30.1)
          redis-client (0.30.1)

      CHECKSUMS
        redis (6.0.0) sha256=#{'a' * 64}
        redis-client (0.30.1) sha256=#{'b' * 64}
    LOCK
  end
  let(:contract) do
    { 'schema' => 2, 'lich5_commit' => 'c' * 40, 'gemfile_sha256' => Digest::SHA256.hexdigest(gemfile),
      'lock_sha256' => Digest::SHA256.hexdigest(lockfile),
      'windows_contract_sha256' => Lich::RuntimeGemContract.new(gemfile: gemfile, lockfile: lockfile).windows_contract_digest(
        { 'ruby_version' => '4.0.9', 'ruby_abi' => '4.0', 'platform' => 'x64-mingw-ucrt', 'gems' => {} }, advertised_members: unit.fetch('members')
      ), 'promotable' => true, 'overrides' => {},
      'ruby_inventory' => { 'ruby_version' => '4.0.9', 'ruby_abi' => '4.0', 'platform' => 'x64-mingw-ucrt', 'gems' => {} } }
  end
  let(:packages) do
    [['redis-client', '0.30.1', 'b'], ['redis', '6.0.0', 'a']].map do |name, version, digest|
      { 'name' => name, 'version' => version, 'filename' => "#{name}-#{version}.gem", 'sha256' => "sha256:#{digest * 64}" }
    end
  end
  let(:unit) do
    { 'id' => 'redis', 'members' => %w[redis redis-client], 'packages' => packages, 'install_order' => %w[redis-client redis],
      'artifact' => { 'url' => 'https://example.org/immutable/bundle.zip', 'filename' => 'bundle.zip', 'archive' => 'zip', 'sha256' => "sha256:#{'d' * 64}" } }
  end
  let(:target) { { 'platform' => 'x64-mingw-ucrt', 'ruby_abi' => '4.0', 'contract' => contract, 'units' => [unit] } }
  let(:manifest) { { 'schema' => 1, 'targets' => [target] } }
  let(:provenance) do
    { 'runtime_contract_sha256' => Lich::RuntimeGemContract.digest(contract),
      'recovery_manifest_sha256' => Digest::SHA256.hexdigest(JSON.generate(manifest)),
      'ruby_installer_version' => '4.0.9-1', 'installer_sha256' => Digest::SHA256.hexdigest('tested executable') }
  end

  def refresh_identity
    contract['windows_contract_sha256'] = Lich::RuntimeGemContract.new(gemfile: gemfile, lockfile: lockfile).windows_contract_digest(
      contract.fetch('ruby_inventory'), build_roles: contract.fetch('build_roles', {}), advertised_members: unit.fetch('members')
    )
  end

  def verify(**options)
    described_class.verify!(gemfile: gemfile, lockfile: lockfile, manifest_bytes: JSON.generate(manifest), provenance: provenance, **options)
  end

  it 'checks the applicable range instead of rejecting retained legacy package versions' do
    legacy = Marshal.load(Marshal.dump(unit))
    legacy['id'] = 'redis-legacy'
    legacy.fetch('packages').first['version'] = '0.20.0'
    unit['lich_versions'] = { 'min_inclusive' => '5.24.0' }
    target['units'] = [legacy, unit]
    expect(verify(lich_version: '5.24.0').fetch('packages').keys).to eq(%w[redis redis-client])
    expect { verify(lich_version: '5.23.0') }.to raise_error(described_class::Error, /version mismatch/)
  end

  it 'accepts the candidate only after matching recovery and installer are available' do
    expect(verify(candidate_sha: 'c' * 40).fetch('packages').keys).to eq(%w[redis redis-client])
  end

  it 'binds the digest to selected members instead of a displaced legacy-only lock member' do
    lockfile.sub!("\nCHECKSUMS", "    ast (2.4.3)\n\nCHECKSUMS")
    lockfile << "  ast (2.4.3) sha256=#{'e' * 64}\n"
    legacy = Marshal.load(Marshal.dump(unit)).merge('id' => 'redis-legacy')
    legacy['members'] << 'ast'
    legacy['install_order'].unshift('ast')
    legacy['packages'].unshift('name' => 'ast', 'version' => '2.4.3', 'filename' => 'ast-2.4.3.gem', 'sha256' => "sha256:#{'e' * 64}")
    unit['lich_versions'] = { 'min_inclusive' => '5.24.0' }
    target['units'] = [legacy, unit]

    reader = Lich::RuntimeGemContract.new(gemfile: gemfile, lockfile: lockfile)
    selected_digest = reader.windows_contract_digest(contract.fetch('ruby_inventory'), advertised_members: %w[redis redis-client])
    all_members = target.fetch('units').flat_map { |entry| entry.fetch('members') }.uniq
    all_digest = reader.windows_contract_digest(contract.fetch('ruby_inventory'), advertised_members: all_members)
    expect(reader.locked_packages).to have_key('ast')
    expect(all_digest).not_to eq(selected_digest)
    contract['windows_contract_sha256'] = selected_digest
    expect(verify(lich_version: '5.24.0').fetch('packages').keys).to eq(%w[redis redis-client])

    contract['windows_contract_sha256'] = all_digest
    provenance['runtime_contract_sha256'] = Lich::RuntimeGemContract.digest(contract)
    provenance['recovery_manifest_sha256'] = Digest::SHA256.hexdigest(JSON.generate(manifest))
    expect { verify(lich_version: '5.24.0') }.to raise_error(described_class::Error, /does not match this Windows projection/)
  end

  it 'rejects Lich-first delivery before the producer serves its lock' do
    contract['windows_contract_sha256'] = '0' * 64
    expect { verify }.to raise_error(described_class::Error, /build and promote this candidate first/)
  end

  it 'accepts dev-only edits while retaining the original producer provenance hashes' do
    provenance
    gemfile << "# consumer-only comment\ngroup :development do\n gem 'rspec'\nend\n"
    lockfile.sub!("\nCHECKSUMS", "    rspec (3.13.0)\n\nCHECKSUMS")
    lockfile << "  rspec (3.13.0) sha256=#{'f' * 64}\n"
    expect { verify }.not_to raise_error
  end

  it 'requires the semantic identity and well-formed raw provenance hashes' do
    contract.delete('windows_contract_sha256')
    expect { verify }.to raise_error(described_class::Error, /windows_contract_sha256/)
    refresh_identity
    contract['gemfile_sha256'] = 'bad'
    expect { verify }.to raise_error(described_class::Error, /invalid gemfile_sha256/)
  end

  it 'keeps the raw producer hashes bound to installer provenance' do
    provenance
    contract['gemfile_sha256'] = '0' * 64
    expect { verify }.to raise_error(described_class::Error, /matching installer predecessor/)
  end

  it 'rejects schema 1 instead of silently applying new eligibility semantics to old contracts' do
    contract['schema'] = 1
    expect { verify }.to raise_error(described_class::Error, /unsupported runtime contract/)
  end

  it 'rejects a runtime requirement change even when the selected version remains valid' do
    provenance
    gemfile.replace("gem 'redis', '>= 5'\n")
    expect { verify }.to raise_error(described_class::Error, /Windows projection/)
  end

  it 'rejects producer-first version drift from the selected consumer lock' do
    packages.first['version'] = '0.30.2'
    expect { verify }.to raise_error(described_class::Error, /version mismatch for redis-client/)
  end

  it 'rejects a different full candidate SHA when one is explicitly selected' do
    expect { verify(candidate_sha: 'e' * 40) }.to raise_error(described_class::Error, /different candidate SHA/)
  end

  it 'accepts identical contract content after a merge changes the consumer commit' do
    expect { verify }.not_to raise_error
  end

  it 'rejects abbreviated producer commit identities' do
    contract['lich5_commit'] = 'abcdef1'
    expect { verify }.to raise_error(described_class::Error, /full lich-5 commit/)
  end

  it 'rejects override builds even if their promotable flag is true' do
    contract['overrides'] = { 'redis' => '7.0.0' }
    expect { verify }.to raise_error(described_class::Error, /override or diagnostic/)
  end

  it 'rejects diagnostic builds even with empty overrides' do
    contract['promotable'] = false
    expect { verify }.to raise_error(described_class::Error, /override or diagnostic/)
  end

  it 'requires the matching installer predecessor' do
    provenance.delete('runtime_contract_sha256')
    expect { verify }.to raise_error(described_class::Error, /matching installer predecessor/)
  end

  it 'rejects an installer built against earlier manifest bytes' do
    provenance
    unit['artifact']['sha256'] = "sha256:#{'e' * 64}"
    expect { verify }.to raise_error(described_class::Error, /matching installer predecessor/)
  end

  it 'rejects a different installer Ruby version' do
    provenance['ruby_installer_version'] = '4.0.5-1'
    expect { verify }.to raise_error(described_class::Error, /installer Ruby version/)
  end

  it 'validates every unit including a malformed shadowed unit' do
    target['units'] << unit.merge('id' => 'shadow', 'install_order' => [])
    expect { verify }.to raise_error(described_class::Error, /install_order/)
  end

  it 'rejects a shadowed transitive version mismatch' do
    target['units'] << Marshal.load(Marshal.dump(unit)).merge('id' => 'shadow')
    target['units'].last['packages'].first['version'] = '0.30.2'
    expect { verify }.to raise_error(described_class::Error, /version mismatch/)
  end

  it 'requires transitive recovery coverage' do
    unit['members'].delete('redis-client')
    expect { verify }.to raise_error(described_class::Error, /does not cover redis-client/)
  end

  it 'rejects advertised membership without the corresponding package' do
    packages.shift
    unit['install_order'].shift
    expect { verify }.to raise_error(described_class::Error, /omits its package/)
  end

  it 'rejects an upstream package with a different checksum than the lock' do
    unit['artifact']['url'] = 'https://rubygems.org/downloads/redis-6.0.0.gem'
    packages.last['sha256'] = "sha256:#{'e' * 64}"
    expect { verify }.to raise_error(described_class::Error, /upstream package checksum mismatch/)
  end

  it 'rejects duplicate target selectors' do
    manifest['targets'] << target
    expect { verify }.to raise_error(described_class::Error, /exactly one/)
  end

  it 'rejects a legacy manifest without contract provenance' do
    target.delete('contract')
    expect { verify }.to raise_error(described_class::Error, /invalid R4L5 contract/)
  end

  it 'checks the actual installer bytes before attachment' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'Ruby4Lich5.exe')
      File.binwrite(path, 'tested executable')
      expect { verify(installer_path: path) }.not_to raise_error
      File.binwrite(path, 'different executable')
      expect { verify(installer_path: path) }.to raise_error(described_class::Error, /downloaded installer checksum/)
    end
  end

  it 'checks an advertised GTK-only non-GTK lock member without requiring unused lock entries' do
    extra = "    red-colors (0.5.0)\n    unused (1.0)\n"
    lockfile.sub!("\nCHECKSUMS", "#{extra}\nCHECKSUMS")
    lockfile << "  red-colors (0.5.0) sha256=#{'e' * 64}\n  unused (1.0) sha256=#{'f' * 64}\n"
    unit['members'] << 'red-colors'
    unit['install_order'].unshift('red-colors')
    packages.unshift('name' => 'red-colors', 'version' => '0.5.0', 'filename' => 'red-colors-0.5.0.gem', 'sha256' => "sha256:#{'e' * 64}")
    expect { verify }.not_to raise_error
    packages.first['version'] = '0.6.0'
    expect { verify }.to raise_error(described_class::Error, /version mismatch for red-colors/)
  end

  it 'accepts producer-owned GTK versions but rejects the same drift outside the GTK role' do
    contract['build_roles'] = { 'gtk' => ['redis-client'] }
    packages.first['version'] = '0.30.2'
    refresh_identity
    expect { verify }.not_to raise_error
    contract['build_roles']['gtk'] = []
    refresh_identity
    expect { verify }.to raise_error(described_class::Error, /version mismatch for redis-client/)
  end

  it 'rejects shipping a RubyInstaller-supplied transitive even with matching provenance' do
    contract['ruby_inventory']['gems']['redis-client'] = { 'version' => '0.30.1', 'dependencies' => {} }
    shipped = packages.shift
    unit['members'].delete('redis-client')
    unit['install_order'].delete('redis-client')
    refresh_identity
    expect(verify.fetch('bundled')).to have_key('redis-client')
    packages.unshift(shipped)
    unit['members'] << 'redis-client'
    unit['install_order'].unshift('redis-client')
    provenance['recovery_manifest_sha256'] = Digest::SHA256.hexdigest(JSON.generate(manifest))
    expect { verify }.to raise_error(described_class::Error, /RubyInstaller-supplied gems must not be shipped: redis-client/)
  end

  it 'parses BOM provenance in the actual CLI and still rejects mismatched semantic digests' do
    require 'open3'
    require_relative '../../.github/scripts/check_r4l5_contract'
    Dir.mktmpdir do |dir|
      inputs = { 'Gemfile' => gemfile, 'Gemfile.lock' => lockfile, 'manifest.json' => JSON.generate(manifest),
                 'provenance.json' => [239, 187, 191].pack('C*') + JSON.generate(provenance).b }
      inputs.each { |name, bytes| File.binwrite(File.join(dir, name), bytes) }
      cli = File.expand_path('../../.github/scripts/check_r4l5_contract.rb', __dir__)
      args = %w[gemfile lockfile manifest provenance].zip(%w[Gemfile Gemfile.lock manifest.json provenance.json]).flat_map { |key, name| ["--#{key}", File.join(dir, name)] }
      output, error, status = Open3.capture3(RbConfig.ruby, cli, *args)
      expect(status.success?).to be(true), error
      expect(output).to include('contract accepted')
      provenance['recovery_manifest_sha256'] = '0' * 64
      File.binwrite(File.join(dir, 'provenance.json'), [239, 187, 191].pack('C*') + JSON.generate(provenance).b)
      _output, error, status = Open3.capture3(RbConfig.ruby, cli, *args)
      expect(status.exitstatus).to eq(1)
      expect(error).to include('matching installer predecessor')
      expect(error).not_to include('unexpected character')
    end
  end

  it 'retains strict publication lifecycle validation despite lenient startup selection' do
    unit['lifecycle'] = { 'state' => 'obsolete', 'reason' => 'unsupported publication key' }
    expect { verify }.to raise_error(described_class::Error, /lifecycle/)
  end

  it 'checks portable ranged inputs with an explicit version and never guesses the next release' do
    require 'open3'
    old = Marshal.load(Marshal.dump(unit)).merge('id' => 'legacy')
    old['packages'].each { |package| package['version'] = '0.1' }
    unit['lich_versions'] = { 'min_inclusive' => '5.24.0' }
    target['units'] = [old, unit]
    Dir.mktmpdir do |dir|
      inputs = { 'Gemfile' => gemfile, 'Gemfile.lock' => lockfile, 'manifest.json' => JSON.generate(manifest), 'provenance.json' => JSON.generate(provenance) }
      inputs.each { |name, bytes| File.binwrite(File.join(dir, name), bytes) }
      cli = File.expand_path('../../.github/scripts/check_r4l5_contract.rb', __dir__)
      args = %w[gemfile lockfile manifest provenance].zip(%w[Gemfile Gemfile.lock manifest.json provenance.json]).flat_map { |key, name| ["--#{key}", File.join(dir, name)] }
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, *args)
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('--lich-version')
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, *args, '--lich-version', '5.24.0')
      expect(status.success?).to be(true), stderr
      expect(stdout).to include('contract accepted')
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, *args, '--lich-version', '5.24.0-beta.1')
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('version mismatch')
      Dir.mkdir(File.join(dir, 'lib'))
      File.write(File.join(dir, 'lib/version.rb'), "LICH_VERSION = '5.23.0'\n")
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, *args)
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('version mismatch')
    end
  end
end
