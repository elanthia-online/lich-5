# frozen_string_literal: true

require 'tmpdir'
require_relative '../../lib/r4l5_contract_check'

RSpec.describe Lich::R4L5ContractCheck do
  let(:gemfile) { "gem 'redis'\n" }
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
    { 'schema' => 1, 'lich5_commit' => 'c' * 40, 'gemfile_sha256' => Digest::SHA256.hexdigest(gemfile),
      'lock_sha256' => Digest::SHA256.hexdigest(lockfile), 'promotable' => true, 'overrides' => {},
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

  def verify(**options)
    described_class.verify!(gemfile: gemfile, lockfile: lockfile, manifest_bytes: JSON.generate(manifest), provenance: provenance, **options)
  end

  it 'accepts the candidate only after matching recovery and installer are available' do
    expect(verify(candidate_sha: 'c' * 40).fetch('packages').keys).to eq(%w[redis redis-client])
  end

  it 'rejects Lich-first delivery before the producer serves its lock' do
    contract['lock_sha256'] = '0' * 64
    expect { verify }.to raise_error(described_class::Error, /build and promote this candidate first/)
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
end
