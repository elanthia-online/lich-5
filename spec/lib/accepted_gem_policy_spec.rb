# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/accepted_gem_policy'

RSpec.describe Lich::AcceptedGemPolicy do
  let(:installed) { {} }
  let(:active) { {} }
  let(:unit) do
    { 'id' => 'sqlite3', 'members' => ['sqlite3'], 'install_order' => ['sqlite3'],
      'packages' => [{ 'name' => 'sqlite3', 'version' => '2.10.2', 'filename' => 'sqlite3-2.10.2.gem', 'sha256' => "sha256:#{'a' * 64}" }] }
  end
  let(:target) { { 'platform' => Gem::Platform.local.to_s, 'units' => [unit], 'contract' => { 'ruby_inventory' => { 'gems' => {} } } } }
  let(:plan) { Lich::DependencyRecovery::Plan.new(units: [unit], target: target) }
  let(:recovery) { instance_double(Lich::DependencyRecovery, policy_plan: plan) }
  let(:dependencies) { [Gem::Dependency.new('sqlite3')] }
  subject(:policy) { described_class.new(recovery: recovery, find_specs: ->(name) { installed.fetch(name, []) }, loaded_specs: active) }

  def spec(name, version, dependencies = {})
    result = Gem::Specification.new do |item|
      item.name = name
      item.version = version
      dependencies.each { |child, requirement| item.add_runtime_dependency(child, requirement) }
    end
    activated = active
    result.define_singleton_method(:activate) { activated[name] = self; true }
    result
  end

  it 'requires an upgrade when only the older sqlite3 is installed' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.1')]
    expect(policy.check(dependencies).needed).to eq(['sqlite3'])
    expect(active).to be_empty
  end

  it 'selects and activates the accepted sqlite3 when old and fixed copies coexist' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.1'), spec('sqlite3', '2.10.2')]
    check = policy.check(dependencies)
    expect(check.needed).to be_empty
    policy.activate!(check)
    expect(active.fetch('sqlite3').version.to_s).to eq('2.10.2')
  end

  it 'requires a restart when the old sqlite3 is already active even if the fixed copy is installed' do
    old = spec('sqlite3', '2.10.1')
    installed['sqlite3'] = [old, spec('sqlite3', '2.10.2')]
    active['sqlite3'] = old
    check = policy.check(dependencies)
    expect(check.needed).to eq(['sqlite3'])
    expect { policy.activate!(check) }.to raise_error(described_class::Error, /require a restart/)
    expect(active.fetch('sqlite3')).to equal(old)
  end

  it 'accepts an eligible newer installation without downgrading it' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.2'), spec('sqlite3', '2.10.3')]
    check = policy.check(dependencies)
    expect(check.needed).to be_empty
    policy.activate!(check)
    expect(active.fetch('sqlite3').version.to_s).to eq('2.10.3')
  end

  it 'retains an already active accepted newer version' do
    newer = spec('sqlite3', '2.10.3')
    installed['sqlite3'] = [spec('sqlite3', '2.10.2'), newer, spec('sqlite3', '2.10.4')]
    active['sqlite3'] = newer
    policy.activate!(policy.check(dependencies))
    expect(active.fetch('sqlite3').version.to_s).to eq('2.10.3')
  end

  it 'detects a missing closure member even if the selected root is present' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.2', 'closure' => '>= 1')]
    unit['members'] << 'closure'
    unit['packages'] << { 'name' => 'closure', 'version' => '1.0', 'filename' => 'closure-1.0.gem', 'sha256' => "sha256:#{'b' * 64}" }
    unit['install_order'].unshift('closure')
    check = policy.check(dependencies)
    expect(check.needed).to eq(['closure'])
    expect(check.plan.units).to eq([unit])
    expect(active).to be_empty
  end

  it 'reports an absent unlisted installed transitive as local damage and accepts its restoration' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.2', 'local-child' => '>= 1')]
    expect(recovery).not_to receive(:recover)
    expect { policy.check(dependencies) }.to raise_error(described_class::LocalInstallationError, /local-child is missing/) do |error|
      expect(error).not_to be_a(described_class::PolicyError)
    end
    expect(active).to be_empty
    installed['local-child'] = [spec('local-child', '1.0')]
    check = policy.check(dependencies)
    expect(check.needed).to be_empty
    policy.activate!(check)
    expect(active.keys).to contain_exactly('local-child', 'sqlite3')
  end

  it 'retains policy classification for an installed transitive that conflicts with requirements' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.2', 'local-child' => '>= 2')]
    installed['local-child'] = [spec('local-child', '1.0')]
    expect { policy.check(dependencies) }.to raise_error(described_class::PolicyError)
    expect(active).to be_empty
  end

  it 'retains policy classification when the accepted floor conflicts with the client requirement' do
    installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
    expect { policy.check([Gem::Dependency.new('sqlite3', '< 2')]) }.to raise_error(described_class::PolicyError)
    expect(active).to be_empty
  end

  it 'honors installed dependency requirements while selecting newer versions' do
    unit['members'] << 'closure'
    unit['packages'] << { 'name' => 'closure', 'version' => '1.0', 'filename' => 'closure-1.0.gem', 'sha256' => "sha256:#{'b' * 64}" }
    installed['sqlite3'] = [spec('sqlite3', '2.10.2', 'closure' => '= 1.0'), spec('sqlite3', '2.10.3', 'closure' => '= 2.0')]
    installed['closure'] = [spec('closure', '1.0'), spec('closure', '2.0')]
    policy.activate!(policy.check(dependencies))
    expect(active.transform_values { |item| item.version.to_s }).to eq('closure' => '2.0', 'sqlite3' => '2.10.3')
  end

  it 'does not fetch an artifact when policy acquisition fails' do
    allow(recovery).to receive(:policy_plan).and_return(Lich::DependencyRecovery::Plan.new(units: [], error: 'service unavailable'))
    expect(recovery).not_to receive(:recover)
    expect { policy.check(dependencies) }.to raise_error(described_class::Error, /service unavailable/)
  end

  it 'reports a policy without this runtime as unsupported rather than as a policy failure' do
    allow(recovery).to receive(:policy_plan).and_return(
      Lich::DependencyRecovery::Plan.new(units: [], error: 'manifest has no target for Ruby 4.0 on aarch64-mingw-ucrt', error_kind: :unsupported_runtime)
    )
    expect { policy.check(dependencies) }.to raise_error(described_class::UnsupportedRuntimeError, /no target/) { |error|
      expect(error).not_to be_a(described_class::PolicyError)
    }
  end

  it 'keeps an otherwise invalid policy an InvalidPolicyError' do
    allow(recovery).to receive(:policy_plan).and_return(Lich::DependencyRecovery::Plan.new(units: [], error: 'duplicate targets', error_kind: :invalid))
    expect { policy.check(dependencies) }.to raise_error(described_class::InvalidPolicyError)
  end

  it 'requires declared roots to be covered by accepted policy or supplied RubyInstaller gems' do
    plan.units = []
    expect { policy.check(dependencies) }.to raise_error(described_class::Error, /does not cover/)
  end

  it 'checks the actual supplied gem against the Gemfile requirement' do
    plan.units = []
    target['contract']['ruby_inventory']['gems']['json'] = { 'version' => '3.1' }
    installed['json'] = [spec('json', '2.0')]
    expect { policy.check([Gem::Dependency.new('json', '>= 3')]) }.to raise_error(described_class::Error, /repair the Ruby installation/)
  end

  it 'enforces the supplied inventory floor even with an unrestricted Gemfile root' do
    plan.units = []
    target['contract']['ruby_inventory']['gems']['json'] = { 'version' => '3.1' }
    installed['json'] = [spec('json', '3.0')]
    expect { policy.check([Gem::Dependency.new('json')]) }.to raise_error(described_class::Error, /repair the Ruby installation/)
  end

  it 'accepts and activates a supplied version at or above its inventory floor' do
    plan.units = []
    target['contract']['ruby_inventory']['gems']['json'] = { 'version' => '3.1' }
    installed['json'] = [spec('json', '3.0'), spec('json', '3.2')]
    policy.activate!(policy.check([Gem::Dependency.new('json')]))
    expect(active.fetch('json').version.to_s).to eq('3.2')
  end

  it 'rejects an unapproved root following a valid supplied root' do
    plan.units = []
    target['contract']['ruby_inventory']['gems']['json'] = { 'version' => '3.1' }
    installed['json'] = [spec('json', '3.1')]
    installed['unapproved'] = [spec('unapproved', '9.0')]
    expect { policy.check([Gem::Dependency.new('json'), Gem::Dependency.new('unapproved')]) }
      .to raise_error(described_class::Error, /does not cover.*unapproved/)
  end

  it 'rejects conflicting package identities across selected units' do
    plan.units << unit.merge('id' => 'other', 'packages' => [unit['packages'].first.merge('version' => '2.10.1')])
    expect { policy.check(dependencies) }.to raise_error(described_class::Error, /conflicting accepted package/)
  end

  it 'detects failed activation instead of assuming the installed version is in use' do
    candidate = spec('sqlite3', '2.10.2')
    candidate.define_singleton_method(:activate) { true }
    installed['sqlite3'] = [candidate]
    expect { policy.activate!(policy.check(dependencies)) }.to raise_error(described_class::Error, /activated a different version/)
  end
  it 'detects old loaded code and activates the accepted version after a fresh start with real RubyGems' do
    Dir.mktmpdir('accepted-gem-policy') do |home|
      FileUtils.mkdir_p(File.join(home, 'specifications'))
      %w[1.0 2.0].each do |version|
        specification = Gem::Specification.new do |item|
          item.name = 'policy_fixture'
          item.version = version
          item.summary = 'Offline activation fixture'
          item.files = ['lib/policy_fixture.rb']
        end
        folder = File.join(home, 'gems', specification.full_name, 'lib')
        FileUtils.mkdir_p(folder)
        File.write(File.join(folder, 'policy_fixture.rb'), "POLICY_FIXTURE_VERSION = #{version.inspect}\n")
        File.write(File.join(home, 'specifications', "#{specification.full_name}.gemspec"), specification.to_ruby)
      end
      program = <<~'RUBY'
        abort 'dependency environment leaked' if ENV['BUNDLER_SETUP'] || ENV['RUBYGEMS_GEMDEPS']
        require ARGV.shift
        home = ARGV.shift
        mode = ARGV.shift
        Gem.use_paths(home, [home])
        Gem::Specification.reset
        unit = { 'members' => ['policy_fixture'], 'packages' => [
          { 'name' => 'policy_fixture', 'version' => '2.0', 'filename' => 'policy_fixture-2.0.gem', 'sha256' => 'a' * 64 }
        ] }
        plan = Lich::DependencyRecovery::Plan.new(units: [unit], target: { 'platform' => Gem::Platform.local.to_s })
        recovery = Object.new
        recovery.define_singleton_method(:policy_plan) { |_| plan }
        policy = Lich::AcceptedGemPolicy.new(recovery: recovery)
        if mode == 'old'
          gem 'policy_fixture', '= 1.0'
          require 'policy_fixture'
          check = policy.check([Gem::Dependency.new('policy_fixture')])
          abort 'loaded old code bypassed policy' unless check.needed == ['policy_fixture'] && POLICY_FIXTURE_VERSION == '1.0'
          puts 'restart-required'
          exit
        end
        policy.activate!(policy.check([Gem::Dependency.new('policy_fixture')]))
        require 'policy_fixture'
        abort 'incorrect selected gem' unless POLICY_FIXTURE_VERSION == '2.0' && Gem.loaded_specs.fetch('policy_fixture').version.to_s == '2.0'
        puts POLICY_FIXTURE_VERSION
      RUBY
      poison = File.join(home, 'must-not-load.rb')
      File.write(poison, "raise 'ambient dependency setup executed'\n")
      original = ENV.to_h.slice('BUNDLER_SETUP', 'RUBYGEMS_GEMDEPS')
      ENV['BUNDLER_SETUP'] = poison
      ENV['RUBYGEMS_GEMDEPS'] = poison
      { 'old' => 'restart-required', 'fresh' => '2.0' }.each do |mode, expected|
        stdout, stderr, status = Open3.capture3(
          { 'GEM_HOME' => home, 'GEM_PATH' => home, 'RUBYOPT' => nil, 'RUBYLIB' => nil,
            'BUNDLER_SETUP' => nil, 'RUBYGEMS_GEMDEPS' => nil },
          RbConfig.ruby, '-e', program, File.expand_path('../../lib/accepted_gem_policy.rb', __dir__), home, mode
        )
        expect(status.success?).to be(true), stderr
        expect(stdout.strip).to eq(expected)
      end
    ensure
      original&.each { |name, value| ENV[name] = value }
      %w[BUNDLER_SETUP RUBYGEMS_GEMDEPS].each { |name| ENV.delete(name) unless original&.key?(name) }
    end
  end

  it 'preserves an acquisition failure category from the actual policy reader' do
    reader = Lich::DependencyRecovery.new(http_get: ->(_url) { raise SocketError, 'fixture offline' })
    actual = described_class.new(recovery: reader, find_specs: ->(_name) { [spec('sqlite3', '2.10.2')] }, loaded_specs: {})
    expect(reader).not_to receive(:recover)
    expect { actual.check(dependencies) }.to raise_error(described_class::AcquisitionError, /fixture offline/)
  end

  it 'preserves a malformed-policy failure category from the actual reader' do
    reader = Lich::DependencyRecovery.new(http_get: ->(_url) { '{invalid' })
    actual = described_class.new(recovery: reader)
    expect { actual.check(dependencies) }.to raise_error(described_class::InvalidPolicyError)
  end

  it 'classifies malformed RubyInstaller inventory as policy failure rather than missing gems' do
    target['contract']['ruby_inventory']['gems'] = ['invalid']
    expect { policy.check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /inventory is malformed/)
  end

  context 'with a package minimum' do
    let(:sqlite3) { unit.fetch('packages').first }

    def redis_unit
      { 'id' => 'redis', 'members' => %w[redis redis-client], 'install_order' => %w[redis-client redis],
        'packages' => [{ 'name' => 'redis-client', 'version' => '0.26.0', 'minimum' => '0.25.0', 'filename' => 'redis-client-0.26.0.gem', 'sha256' => "sha256:#{'c' * 64}" },
                       { 'name' => 'redis', 'version' => '5.4.1', 'filename' => 'redis-5.4.1.gem', 'sha256' => "sha256:#{'d' * 64}" }] }
    end

    before { sqlite3['minimum'] = '2.10.1' }

    it 'requires a repair only below the minimum' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.0')]
      check = policy.check(dependencies)
      expect(check.needed).to eq(['sqlite3'])
      expect(check.recommended).to eq([])
      expect(check.plan.units).to eq([unit])
    end

    it 'starts on an installed version at the minimum and reports the accepted version as recommended' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.0'), spec('sqlite3', '2.10.1')]
      check = policy.check(dependencies)
      expect(check.needed).to be_empty
      expect(check.recommended).to eq(['sqlite3'])
      policy.activate!(check)
      expect(active.fetch('sqlite3').version.to_s).to eq('2.10.1')
    end

    it 'still activates the highest acceptable installed version, recommending nothing once the accepted one is present' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.1'), spec('sqlite3', '2.10.2')]
      check = policy.check(dependencies)
      expect(check.recommended).to eq([])
      policy.activate!(check)
      expect(active.fetch('sqlite3').version.to_s).to eq('2.10.2')
    end

    it 'keeps an already active version between the minimum and the accepted version without a restart' do
      old = spec('sqlite3', '2.10.1')
      installed['sqlite3'] = [old, spec('sqlite3', '2.10.2')]
      active['sqlite3'] = old
      check = policy.check(dependencies)
      expect(check.needed).to be_empty
      expect(check.recommended).to eq(['sqlite3'])
      policy.activate!(check)
      expect(active.fetch('sqlite3')).to equal(old)
    end

    it 'still requires a restart when the active version is below the minimum' do
      old = spec('sqlite3', '2.10.0')
      installed['sqlite3'] = [old, spec('sqlite3', '2.10.2')]
      active['sqlite3'] = old
      expect(policy.check(dependencies).needed).to eq(['sqlite3'])
    end

    it 'repairs a recommended package together with a needed member of the same unit' do
      unit['members'] << 'closure'
      unit['packages'] << { 'name' => 'closure', 'version' => '1.0', 'filename' => 'closure-1.0.gem', 'sha256' => "sha256:#{'b' * 64}" }
      unit['install_order'].unshift('closure')
      installed['sqlite3'] = [spec('sqlite3', '2.10.1', 'closure' => '>= 1')]
      check = policy.check(dependencies)
      expect(check.needed).to eq(['closure'])
      expect(check.plan.units).to eq([unit])
      expect(check.plan.units.first.fetch('packages').map { |package| package.fetch('name') }).to include('sqlite3')
    end

    it 'repairs, instead of stopping, when an installed newer dependent needs more than a member minimum (review case B)' do
      plan.units = [unit, redis_unit]
      installed['sqlite3'] = [spec('sqlite3', '2.10.1')]
      installed['redis'] = [spec('redis', '5.5.0', 'redis-client' => '>= 0.26')]
      installed['redis-client'] = [spec('redis-client', '0.25.0')]
      check = policy.check([Gem::Dependency.new('redis'), Gem::Dependency.new('sqlite3')])
      expect(check.needed).to eq(['redis-client'])
      # Only the unit named by the failure is repaired; sqlite3 stays log-only.
      expect(check.plan.units.map { |item| item.fetch('id') }).to eq(['redis'])
      expect(active).to be_empty
    end

    it 'repairs a case B conflict with an active member below its version' do
      plan.units = [redis_unit]
      old = spec('redis-client', '0.25.0')
      installed['redis'] = [spec('redis', '5.5.0', 'redis-client' => '>= 0.26')]
      installed['redis-client'] = [old, spec('redis-client', '0.27.0')]
      active['redis-client'] = old
      check = policy.check([Gem::Dependency.new('redis')])
      expect(check.needed).to eq(['redis-client'])
      expect(check.plan.units.map { |item| item.fetch('id') }).to eq(['redis'])
    end

    it 'falls back to the accepted versions when an unlisted transitive rejects the minimum' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.1', 'local-child' => '>= 2')]
      installed['local-child'] = [spec('local-child', '1.0')]
      check = policy.check(dependencies)
      expect(check.needed).to eq(['sqlite3'])
      expect(check.plan.units).to eq([unit])
    end

    it 'keeps local damage a LocalInstallationError' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.2', 'local-child' => '>= 1')]
      expect { policy.check(dependencies) }.to raise_error(described_class::LocalInstallationError, /local-child is missing/)
    end

    it 'keeps a client requirement the accepted version cannot meet a PolicyError' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      expect { policy.check([Gem::Dependency.new('sqlite3', '< 2')]) }.to raise_error(described_class::PolicyError, /cannot satisfy/)
    end

    it 'rejects units that disagree on the minimum of a shared package' do
      plan.units << unit.merge('id' => 'other', 'packages' => [sqlite3.merge('minimum' => '2.10.0')])
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      expect { policy.check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /conflicting accepted package/)
    end

    it 'treats an absent minimum and one equal to the version as the same package' do
      sqlite3.delete('minimum')
      plan.units << unit.merge('id' => 'other', 'packages' => [sqlite3.merge('minimum' => '2.10.2')])
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      expect(policy.check(dependencies).needed).to be_empty
    end

    it 'treats an absent minimum and one equal in value to the version as the same package' do
      sqlite3.delete('minimum')
      plan.units << unit.merge('id' => 'other', 'packages' => [sqlite3.merge('minimum' => '2.10.2.0')])
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      expect(policy.check(dependencies).needed).to be_empty
    end

    it 'still rejects an absent minimum against a lower one for the same package' do
      sqlite3.delete('minimum')
      plan.units << unit.merge('id' => 'other', 'packages' => [sqlite3.merge('minimum' => '2.10.1')])
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      expect { policy.check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /conflicting accepted package identities for sqlite3/)
    end
  end

  it 'gives a minimum equal to the version exactly the strict results' do
    scenarios = [
      [[%w[sqlite3 2.10.1]], {}],
      [[%w[sqlite3 2.10.1], %w[sqlite3 2.10.2]], {}],
      [[%w[sqlite3 2.10.2], %w[sqlite3 2.10.3]], {}],
      [[%w[sqlite3 2.10.1], %w[sqlite3 2.10.2]], { 'sqlite3' => '2.10.1' }]
    ]
    scenarios.each do |versions, loaded|
      results = [nil, '2.10.2'].map do |minimum|
        package = unit.fetch('packages').first
        minimum ? package['minimum'] = minimum : package.delete('minimum')
        installed['sqlite3'] = versions.map { |name, version| spec(name, version) }
        active.clear
        loaded.each { |name, version| active[name] = installed.fetch(name).find { |item| item.version.to_s == version } }
        check = policy.check(dependencies)
        [check.needed, check.specs.map(&:full_name), check.plan.units.map { |item| item.fetch('id') }, check.recommended]
      end
      expect(results.last).to eq(results.first)
    end
  end

  context 'when validating a served minimum' do
    let(:artifact) { { 'url' => 'https://example.invalid/sqlite3-2.10.2.gem', 'archive' => 'gem', 'filename' => 'sqlite3-2.10.2.gem', 'sha256' => "sha256:#{'a' * 64}" } }

    def served(minimum)
      package = unit.fetch('packages').first.dup
      minimum == :absent ? package.delete('minimum') : package['minimum'] = minimum
      document = { 'schema' => 1, 'targets' => [{ 'ruby_abi' => RUBY_VERSION.split('.').first(2).join('.'), 'platform' => Gem::Platform.local.to_s,
                                                  'units' => [unit.merge('artifact' => artifact, 'packages' => [package])] }] }
      reader = Lich::DependencyRecovery.new(http_get: ->(_url) { JSON.generate(document) })
      described_class.new(recovery: reader, find_specs: ->(name) { installed.fetch(name, []) }, loaded_specs: active)
    end

    it 'rejects a minimum that is not a version or is above the version' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      ['2.10.3', 'not a version', '', 2].each do |minimum|
        expect { served(minimum).check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /minimum is (?:invalid|above its version)/)
      end
    end

    it 'rejects a blank, padded or rewritten minimum that would otherwise pass as a version' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.2')]
      [' ', ' 2.10.1', '2.10.1 ', "2.10.1\n", '2.10.1-1'].each do |minimum|
        expect(Gem::Version.correct?(minimum)).to be(true)
        expect { served(minimum).check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /minimum is invalid/)
      end
    end

    it 'does not start on a version below the strict floor through a blank minimum' do
      installed['sqlite3'] = [spec('sqlite3', '1.3.0')]
      expect { served(' ').check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /minimum is invalid/)
    end

    it 'rejects a canonical prerelease minimum, which startup could never run on' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.2.rc1')]
      expect { served('2.10.2.rc1').check(dependencies) }.to raise_error(described_class::InvalidPolicyError, /minimum is invalid/)
    end

    it 'applies the strict floor when the minimum is absent and the relaxed one when it is present' do
      installed['sqlite3'] = [spec('sqlite3', '2.10.1')]
      expect(served(:absent).check(dependencies).needed).to eq(['sqlite3'])
      expect(served('2.10.2').check(dependencies).needed).to eq(['sqlite3'])
      check = served('2.10.1').check(dependencies)
      expect(check.needed).to be_empty
      expect(check.recommended).to eq(['sqlite3'])
    end
  end
end
