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
end
