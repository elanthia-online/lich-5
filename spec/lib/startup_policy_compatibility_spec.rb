# frozen_string_literal: true

require 'tmpdir'
require 'open3'
require_relative '../../lib/startup_policy_compatibility'

RSpec.describe Lich::StartupPolicyCompatibility do
  let(:unit) do
    { 'id' => 'sqlite3', 'members' => ['sqlite3'], 'install_order' => ['sqlite3'],
      'artifact' => { 'url' => 'https://example.invalid/sqlite3-2.10.2.gem', 'archive' => 'gem', 'filename' => 'sqlite3-2.10.2.gem', 'sha256' => "sha256:#{'a' * 64}" },
      'packages' => [{ 'name' => 'sqlite3', 'version' => '2.10.2', 'filename' => 'sqlite3-2.10.2.gem', 'sha256' => "sha256:#{'a' * 64}" }] }
  end
  let(:target) { { 'platform' => Gem::Platform.local.to_s, 'ruby_abi' => RUBY_VERSION.split('.')[0, 2].join('.'), 'units' => [unit] } }
  let(:manifest) { { 'schema' => 1, 'targets' => [target] } }
  let(:clients) do
    [{ 'id' => 'supported-older', 'groups' => ['default'], 'gemfile' => "gem 'sqlite3', '>= 2.10', '< 3'" },
     { 'id' => 'supported-current', 'groups' => ['default'], 'gemfile' => "gem 'sqlite3', '~> 2.10.2'" }]
  end

  def verify
    described_class.verify!(manifest_bytes: JSON.generate(manifest), clients: clients)
  end

  it 'checks both client requirement sets without fetching, installing or activating gems' do
    expect_any_instance_of(Lich::DependencyRecovery).not_to receive(:recover)
    expect_any_instance_of(URI::HTTPS).not_to receive(:open)
    expect(Gem::Specification).not_to receive(:find_all_by_name)
    expect_any_instance_of(Gem::Specification).not_to receive(:activate)
    expect(verify.keys).to eq(%w[supported-older supported-current])
  end

  it 'rejects schema changes that break a supported reader' do
    manifest['schema'] = 2
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-older.*unsupported manifest schema/)
  end

  it 'rejects retirement of the supported Ruby ABI target' do
    target['ruby_abi'] = '99.0'
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-older.*no target/)
  end

  it 'rejects retirement of a supported platform target' do
    target['platform'] = 'unsupported-platform'
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-older.*no target/)
  end

  it 'rejects dropping a required root even if other units remain valid' do
    clients.last['gemfile'] += "\ngem 'removed-root'"
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-current.*does not cover.*removed-root/)
  end

  it 'rejects a new floor outside the older supported client requirement' do
    clients.first['gemfile'] = "gem 'sqlite3', '< 2.10.2'"
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-older.*cannot satisfy/)
  end

  it 'rejects malformed and empty support matrices instead of vacuous success' do
    expect { described_class.verify!(manifest_bytes: '{}', clients: []) }.to raise_error(ArgumentError, /nonempty/)
    clients.last['id'] = clients.first['id']
    expect { verify }.to raise_error(ArgumentError, /unique/)
  end

  it 'runs the offline CLI with explicit client files and rejects incompatible proposals' do
    Dir.mktmpdir do |dir|
      clients.each { |client| File.write(File.join(dir, client['id']), client['gemfile']) }
      matrix = clients.map { |client| client.merge('gemfile' => client['id']) }
      File.write(File.join(dir, 'clients.json'), JSON.generate(matrix))
      manifest_path = File.join(dir, 'manifest.json')
      File.write(manifest_path, JSON.generate(manifest))
      cli = File.expand_path('../../.github/scripts/check_supported_startup_policy.rb', __dir__)
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, manifest_path, File.join(dir, 'clients.json'))
      expect(status.success?).to be(true), stderr
      expect(stdout).to include('supported-older', 'supported-current')
      File.write(File.join(dir, 'supported-older'), "gem 'sqlite3', '< 2.10.2'")
      _stdout, stderr, status = Open3.capture3(RbConfig.ruby, cli, manifest_path, File.join(dir, 'clients.json'))
      expect(status.exitstatus).to eq(1)
      expect(stderr).to include('supported-older')
    end
  end

  it 'requires explicit startup groups so graphical or optional client modes cannot be silently omitted' do
    clients.first.delete('groups')
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /supported-older.*groups/)
  end

  it 'requires each supported client version when proposed policy uses ranges' do
    target['units'] << Marshal.load(Marshal.dump(unit)).merge('id' => 'modern', 'lich_versions' => { 'min_inclusive' => '5.24.0' })
    expect { verify }.to raise_error(Lich::AcceptedGemPolicy::PolicyError, /running Lich version is required/)
    clients.each { |client| client['lich_version'] = '5.24.0' }
    expect(verify.keys).to eq(%w[supported-older supported-current])
  end
end
