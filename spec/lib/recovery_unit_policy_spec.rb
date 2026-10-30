# frozen_string_literal: true

require 'tmpdir'
require_relative '../../lib/recovery_unit_policy'
require_relative '../../lib/accepted_gem_policy'

RSpec.describe Lich::RecoveryUnitPolicy do
  def unit(id = 'os', filename: 'os-1.0.gem')
    { 'id' => id, 'members' => ['os'], 'install_order' => ['os'],
      'artifact' => { 'url' => "https://example.invalid/#{filename}", 'filename' => filename, 'archive' => 'gem', 'sha256' => "sha256:#{'a' * 64}" },
      'packages' => [{ 'name' => 'os', 'version' => '1.0', 'sha256' => "sha256:#{'a' * 64}", 'filename' => filename }] }
  end

  let(:legacy) { unit }
  let(:modern) { unit('modern').merge('lich_versions' => { 'min_inclusive' => '5.24.0', 'max_exclusive' => '6.0' }) }
  let(:target) { { 'platform' => Gem::Platform.local.to_s, 'ruby_abi' => RUBY_VERSION.split('.')[0, 2].join('.'), 'units' => [legacy, modern] } }

  [
    { 'state' => 'obsolete' },
    { 'state' => 'obsolete', 'until_date' => '2024-02-29' },
    { 'state' => 'obsolete', 'floor_lich_version' => '5.24.0-beta.0' }
  ].each do |metadata|
    it "strictly accepts lifecycle metadata #{metadata.inspect}" do
      legacy['lifecycle'] = metadata
      expect(described_class.validate!(target)).to be(true)
    end
  end

  [nil, [], 'obsolete', {}, { 'state' => 'withdrawn' },
   { 'state' => 'obsolete', 'reason' => 'unknown publication key' },
   { 'state' => 'obsolete', 'until_date' => '2025-02-29' },
   { 'state' => 'obsolete', 'until_date' => '2026-1-1' },
   { 'state' => 'obsolete', 'until_date' => 20261030 },
   { 'state' => 'obsolete', 'floor_lich_version' => '' },
   { 'state' => 'obsolete', 'floor_lich_version' => 'invalid' },
   { 'state' => 'obsolete', 'until_date' => '2026-10-30', 'floor_lich_version' => '5.24' }].each do |metadata|
    it "strictly rejects lifecycle metadata #{metadata.inspect}" do
      legacy['lifecycle'] = metadata
      expect { described_class.validate!(target) }.to raise_error(described_class::Error, /lifecycle/)
    end
  end

  it 'keeps direct selection strict when used at a publication boundary' do
    legacy['lifecycle'] = { 'state' => 'future', 'reason' => 'documentation' }
    expect { described_class.select(target, '5.24.0', strict: true) }.to raise_error(described_class::Error, /lifecycle/)
    expect(described_class.select(target, '5.24.0')).to eq([modern])
  end

  it 'tolerates annotations but still checks known range values, ordering and withdrawals at startup' do
    modern['lich_versions']['reason'] = { 'annotation' => 'future description' }
    expect(described_class.select(target, '5.24')).to eq([modern])
    expect { described_class.validate!(target) }.to raise_error(described_class::Error, /invalid Lich version range/)
    modern['lich_versions']['max_exclusive'] = '5.0'
    expect { described_class.select(target, '5.24') }.to raise_error(described_class::Error, /empty Lich version range/)
    modern['lich_versions']['max_exclusive'] = '6.0'
    target['withdrawn_members'] = ['os']
    expect { described_class.select(target, '5.24') }.to raise_error(described_class::Error, /withdrawn member/)
  end

  it 'ignores an unknown upper-bound key at startup but rejects publishing that shape' do
    modern['lich_versions'] = { 'min_inclusive' => '5.24.0', 'max_inclusive' => '6.0' }
    expect(described_class.select(target, '7.0')).to eq([modern])
    expect { described_class.select(target, '7.0', strict: true) }.to raise_error(described_class::Error, /invalid Lich version range/)
  end

  it 'does not turn an unknown-only range into unbounded recovery' do
    modern['lich_versions'] = { 'future_rule' => 'selection needs a new capability' }
    expect { described_class.select(target, '5.24') }.to raise_error(described_class::Error, /invalid Lich version range/)
  end

  it 'uses literal beta/stable and inclusive/exclusive boundary semantics' do
    expect(described_class.select(target, '5.24.0-beta.1')).to eq([legacy])
    expect(described_class.select(target, '5.24.0')).to eq([modern])
    expect(described_class.select(target, '6.0')).to eq([legacy])
    modern['lich_versions']['min_inclusive'] = '5.24.0-beta.0'
    expect(described_class.select(target, '5.24.0-beta.1')).to eq([modern])
  end

  it 'starts a healthy installation despite unrelated lifecycle documentation' do
    unrelated = unit('unrelated').merge('members' => ['unrelated'], 'install_order' => ['unrelated'])
    unrelated['packages'] = [unrelated['packages'].first.merge('name' => 'unrelated')]
    unrelated['lifecycle'] = { 'state' => 'future', 'reason' => 'annotation', 'until_date' => 'invalid documentary value' }
    target['units'] = [legacy, unrelated]
    manifest = { 'schema' => 1, 'targets' => [target] }
    installed = Gem::Specification.new { |spec| spec.name = 'os'; spec.version = '1.0' }
    recovery = Lich::DependencyRecovery.new(http_get: ->(_url) { JSON.generate(manifest) }, lich_version: '5.24')
    policy = Lich::AcceptedGemPolicy.new(recovery: recovery, find_specs: ->(name) { name == 'os' ? [installed] : [] }, loaded_specs: {})
    expect(policy.check([Gem::Dependency.new('os')]).needed).to be_empty
  end

  it 'accepts same-platform aliases and rejects native/pure ambiguity in either unit order' do
    alias_unit = unit('alias', filename: 'prefixed-os-1.0.gem').merge('lich_versions' => modern['lich_versions'])
    [[modern, alias_unit], [alias_unit, modern]].each do |ranged|
      target['units'] = [legacy] + ranged
      expect(described_class.select(target, '5.24')).to eq(ranged)
    end
    alias_unit['packages'].first['filename'] = "os-1.0-#{target.fetch('platform')}.gem"
    [[modern, alias_unit], [alias_unit, modern]].each do |ranged|
      target['units'] = [legacy] + ranged
      expect { described_class.select(target, '5.24') }.to raise_error(described_class::Error, /ambiguous ranged/)
    end
  end

  it 'uses consistent platform identity in accepted policy and helper payloads in either order' do
    aliases = [unit('first'), unit('second', filename: 'prefixed-os-1.0.gem')]
    installed = Gem::Specification.new { |spec| spec.name = 'os'; spec.version = '1.0' }
    Dir.mktmpdir do |dir|
      aliases.permutation.each do |ordered|
        plan = Lich::DependencyRecovery::Plan.new(units: ordered, target: target)
        recovery = Object.new
        recovery.define_singleton_method(:policy_plan) { |_names| plan }
        policy = Lich::AcceptedGemPolicy.new(recovery: recovery, find_specs: ->(_name) { [installed] }, loaded_specs: {})
        expect(policy.check([Gem::Dependency.new('os')]).needed).to be_empty
        staged = ordered.map { |entry| { unit: entry, package_paths: { 'os' => File.join(dir, entry['packages'].first['filename']) } } }
        helper = Lich::DependencyRecovery.new(helper_launcher: ->(_path) {})
        helper.send(:schedule_runtime_replacement, staged, dir)
        payload = JSON.parse(File.read(File.join(dir, 'native-runtime-replacement.json')))
        expect(described_class.package_platform(payload['packages'].first, target['platform'])).to eq('ruby')
      end
      aliases.last['packages'].first['filename'] = "os-1.0-#{target.fetch('platform')}.gem"
      aliases.permutation.each do |ordered|
        plan = Lich::DependencyRecovery::Plan.new(units: ordered, target: target)
        recovery = Object.new
        recovery.define_singleton_method(:policy_plan) { |_names| plan }
        policy = Lich::AcceptedGemPolicy.new(recovery: recovery, find_specs: ->(_name) { [installed] }, loaded_specs: {})
        expect { policy.check([Gem::Dependency.new('os')]) }.to raise_error(Lich::AcceptedGemPolicy::InvalidPolicyError, /conflicting accepted/)
        staged = ordered.map { |entry| { unit: entry, package_paths: { 'os' => File.join(dir, entry['packages'].first['filename']) } } }
        helper = Lich::DependencyRecovery.new(helper_launcher: ->(_path) { raise 'must not launch' })
        expect { helper.send(:schedule_runtime_replacement, staged, dir) }.to raise_error(Lich::DependencyRecovery::Error, /conflicting replacement/)
      end
    end
  end
end
