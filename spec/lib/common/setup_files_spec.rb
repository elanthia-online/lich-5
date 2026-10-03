# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/settings_transformer'
require 'common/setup_files'

RSpec.describe Lich::Common::SetupFiles do
  let(:tmpdir) { Dir.mktmpdir('setup-files-test') }
  let(:profiles_dir) { File.join(tmpdir, 'profiles') }
  let(:data_dir) { File.join(tmpdir, 'data') }
  let(:custom_data_dir) { File.join(data_dir, 'custom') }
  let(:setup_files) { described_class.new }

  # Adds a key to `parent` from inside Marshal.dump while `parent` is being
  # iterated, for its first `fail_times` dumps. Ruby itself raises
  # "can't add a new key into hash during iteration".
  let(:flaky_class) do
    Class.new do
      attr_reader :dumps
      attr_accessor :parent

      def initialize(fail_times)
        @fail_times = fail_times
        @dumps = 0
      end

      def _dump(_level)
        @dumps += 1
        @parent[:"added_#{@dumps}"] = true if @dumps <= @fail_times
        ''
      end

      def self._load(_str)
        new(0)
      end
    end
  end

  before do
    stub_const('SCRIPT_DIR', tmpdir)
    FileUtils.mkdir_p(profiles_dir)
    FileUtils.mkdir_p(data_dir)
    allow(setup_files).to receive(:echo)
    allow(setup_files).to receive(:checkname).and_return('TestChar')
  end

  after { FileUtils.remove_entry(tmpdir, true) }

  describe 'FileInfo' do
    let(:file_info) do
      described_class::FileInfo.new(
        path: '/tmp',
        name: 'test.yaml',
        data: { setting: 'value', nested: { key: 'inner' } },
        mtime: Time.now
      )
    end

    it 'deep clones data to prevent mutation' do
      data1 = file_info.data
      data1[:setting] = 'changed'
      expect(file_info.data[:setting]).to eq('value')
    end

    it 'peeks at a single property with deep clone' do
      nested = file_info.peek(:nested)
      nested[:key] = 'mutated'
      expect(file_info.peek(:nested)[:key]).to eq('inner')
    end

    it 'returns nil for missing properties' do
      expect(file_info.peek(:missing)).to be_nil
    end

    it 'formats to_s as filepath' do
      expect(file_info.to_s).to eq('/tmp/test.yaml')
    end

    describe 'deep copy resilience' do
      before do
        stub_const('FlakyDump', flaky_class)
        allow(Lich).to receive(:log)
      end

      def file_info_with(data)
        described_class::FileInfo.new(path: '/tmp', name: 'flaky.yaml', data: data, mtime: Time.now)
      end

      it 'retries a transient iteration error and returns a full copy' do
        flaky = FlakyDump.new(1)
        data = { setting: 'value', flaky: flaky }
        flaky.parent = data

        copy = file_info_with(data).data

        expect(copy[:setting]).to eq('value')
        expect(copy[:flaky]).to be_a(FlakyDump)
        expect(flaky.dumps).to eq(2)
      end

      it 'retries a transient iteration error in peek' do
        flaky = FlakyDump.new(2)
        nested = { key: 'inner', flaky: flaky }
        flaky.parent = nested

        copy = file_info_with({ nested: nested }).peek(:nested)

        expect(copy[:key]).to eq('inner')
        expect(flaky.dumps).to eq(3)
      end

      it 'logs each retry' do
        flaky = FlakyDump.new(2)
        data = { flaky: flaky }
        flaky.parent = data

        file_info_with(data).data

        expect(Lich).to have_received(:log).with(/retrying deep copy of \/tmp\/flaky\.yaml \(attempt 1\): can't add a new key/)
        expect(Lich).to have_received(:log).with(/\(attempt 2\)/)
      end

      it 're-raises after DEEP_COPY_ATTEMPTS failed attempts' do
        flaky = FlakyDump.new(Float::INFINITY)
        data = { flaky: flaky }
        flaky.parent = data

        expect { file_info_with(data).data }.to raise_error(RuntimeError, /during iteration/)
        expect(flaky.dumps).to eq(described_class::FileInfo::DEEP_COPY_ATTEMPTS)
      end

      it 'does not retry unrelated RuntimeErrors' do
        calls = 0
        boom = Class.new do
          define_method(:_dump) do |_level|
            calls += 1
            raise 'boom'
          end
        end
        stub_const('BoomDump', boom)

        expect { file_info_with({ boom: BoomDump.new }).data }.to raise_error(RuntimeError, 'boom')
        expect(calls).to eq(1)
        expect(Lich).not_to have_received(:log)
      end

      it 'does not retry non-RuntimeErrors' do
        data = { hash: Hash.new { |h, k| h[k] = 0 } }

        expect { file_info_with(data).data }.to raise_error(TypeError, /default proc/)
        expect(Lich).not_to have_received(:log)
      end

      it 'leaves the cached data intact after a retry' do
        flaky = FlakyDump.new(1)
        data = { setting: 'value', flaky: flaky }
        flaky.parent = data
        info = file_info_with(data)

        info.data

        # The failed attempt's insert raised, so no key was added.
        expect(data.keys).to eq(%i[setting flaky])
        expect(info.peek(:setting)).to eq('value')
      end
    end
  end

  describe '#get_settings' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { hometown: 'Crossing', loot_coins: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), { loot_additions: [], loot_subtractions: [] }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { hometown: 'Shard' }.to_yaml)
    end

    it 'returns an OpenStruct' do
      result = setup_files.get_settings
      expect(result).to be_a(OpenStruct)
    end

    it 'merges base and character settings (character wins)' do
      result = setup_files.get_settings
      expect(result.hometown).to eq('Shard')
    end

    it 'includes base defaults for nil settings' do
      result = setup_files.get_settings
      expect(result.loot_coins).to eq(true)
    end

    it 'survives a transient iteration error while cloning cached data' do
      stub_const('FlakyDump', flaky_class)
      allow(Lich).to receive(:log)
      flaky = FlakyDump.new(1)
      allow(setup_files).to receive(:safe_load_yaml).and_wrap_original do |original, filepath|
        loaded = original.call(filepath)
        if File.basename(filepath) == 'TestChar-setup.yaml'
          loaded[:flaky] = flaky
          flaky.parent = loaded
        end
        loaded
      end

      result = setup_files.get_settings

      expect(result.hometown).to eq('Shard')
      expect(result.flaky).to be_a(FlakyDump)
      expect(flaky.dumps).to eq(2)
    end
  end

  describe '#get_data' do
    before do
      File.write(File.join(data_dir, 'base-spells.yaml'), { spell_data: { 'Shield' => { 'mana' => 3 } } }.to_yaml)
    end

    it 'returns data as an OpenStruct' do
      result = setup_files.get_data('spells')
      expect(result).to be_a(OpenStruct)
    end

    it 'survives a transient iteration error while cloning cached data' do
      stub_const('FlakyDump', flaky_class)
      allow(Lich).to receive(:log)
      flaky = FlakyDump.new(1)
      allow(setup_files).to receive(:safe_load_yaml).and_wrap_original do |original, filepath|
        loaded = original.call(filepath)
        if File.basename(filepath) == 'base-spells.yaml'
          loaded[:flaky] = flaky
          flaky.parent = loaded
        end
        loaded
      end

      result = setup_files.get_data('spells')

      expect(result.spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
      expect(flaky.dumps).to eq(2)
    end

    it 'loads data from the correct file' do
      result = setup_files.get_data('spells')
      expect(result.spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
    end

    context 'with a custom data file' do
      before { FileUtils.mkdir_p(custom_data_dir) }

      it 'prefers scripts/data/custom over scripts/data' do
        File.write(File.join(custom_data_dir, 'base-spells.yaml'), { spell_data: { 'Shield' => { 'mana' => 99 } } }.to_yaml)
        result = setup_files.get_data('spells')
        expect(result.spell_data).to eq({ 'Shield' => { 'mana' => 99 } })
      end

      it 'loads a custom-only data file with no base equivalent' do
        File.write(File.join(custom_data_dir, 'base-custom.yaml'), { my_setting: 'mine' }.to_yaml)
        result = setup_files.get_data('custom')
        expect(result.my_setting).to eq('mine')
      end

      it 'falls back to scripts/data when no custom file exists' do
        result = setup_files.get_data('spells')
        expect(result.spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
      end

      it 'falls back to scripts/data after a custom file is removed' do
        custom_file = File.join(custom_data_dir, 'base-spells.yaml')
        File.write(custom_file, { spell_data: { 'Shield' => { 'mana' => 99 } } }.to_yaml)
        expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 99 } })

        File.delete(custom_file)
        setup_files.reload
        expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
      end
    end
  end

  # Regression coverage for issue #1596: the cache must key freshness on file
  # content, not mtime. These specs pin File.mtime to a single frozen value so
  # every write shares an mtime -- the exact same-tick collision that occurs on
  # coarse-granularity filesystems (Windows, some CI mounts). They fail against
  # the old mtime-only cache and pass with content-hash freshness, and they do
  # not depend on the host filesystem's timestamp resolution or on sleeps.
  describe 'cache freshness (filesystem-timing-independent)' do
    before { allow(File).to receive(:mtime).and_return(Time.now) }

    it 'reloads a rewritten data file whose mtime did not change' do
      data_file = File.join(data_dir, 'base-spells.yaml')
      File.write(data_file, { spell_data: { 'Shield' => { 'mana' => 3 } } }.to_yaml)
      expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 3 } })

      File.write(data_file, { spell_data: { 'Shield' => { 'mana' => 7 } } }.to_yaml)
      setup_files.reload
      expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 7 } })
    end

    it 'falls back to scripts/data after a same-mtime custom override is removed' do
      FileUtils.mkdir_p(custom_data_dir)
      File.write(File.join(data_dir, 'base-spells.yaml'), { spell_data: { 'Shield' => { 'mana' => 3 } } }.to_yaml)
      custom_file = File.join(custom_data_dir, 'base-spells.yaml')
      File.write(custom_file, { spell_data: { 'Shield' => { 'mana' => 99 } } }.to_yaml)
      expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 99 } })

      File.delete(custom_file)
      setup_files.reload
      expect(setup_files.get_data('spells').spell_data).to eq({ 'Shield' => { 'mana' => 3 } })
    end

    it 'picks up a settings change when the profile mtime did not change' do
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
      expect(setup_files.get_settings.version).to eq(1)

      File.write(File.join(profiles_dir, 'base.yaml'), { version: 2 }.to_yaml)
      setup_files.reload
      expect(setup_files.get_settings.version).to eq(2)
    end
  end

  describe '#reload' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
    end

    it 'reloads changed files' do
      setup_files.get_settings
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 2 }.to_yaml)
      setup_files.reload
      result = setup_files.get_settings
      expect(result.version).to eq(2)
    end
  end

  describe 'cascading includes' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { base_setting: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { include: ['combat'] }.to_yaml)
      File.write(File.join(profiles_dir, 'include-combat.yaml'), { combat_style: 'aggressive', include: ['weapons'] }.to_yaml)
      File.write(File.join(profiles_dir, 'include-weapons.yaml'), { primary_weapon: 'sword' }.to_yaml)
    end

    it 'resolves nested includes depth-first' do
      result = setup_files.get_settings
      expect(result.primary_weapon).to eq('sword')
      expect(result.combat_style).to eq('aggressive')
      expect(result.base_setting).to eq(true)
    end

    it 'character settings override included settings' do
      File.write(File.join(profiles_dir, 'include-combat.yaml'), { combat_style: 'aggressive', hometown: 'Dirge' }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { include: ['combat'], hometown: 'Shard' }.to_yaml)
      result = setup_files.get_settings
      expect(result.hometown).to eq('Shard')
    end
  end

  describe 'caching' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { cached: true }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
    end

    it 'does not re-read unchanged files' do
      setup_files.get_settings
      # Spy on safe_load_yaml to verify it's not called again
      expect(setup_files).not_to receive(:safe_load_yaml).with(File.join(profiles_dir, 'base.yaml'))
      setup_files.get_settings
    end
  end

  describe 'union_keys' do
    before do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp afk]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), { 'empty_values' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-empty.yaml'), { 'empty_values' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-spells.yaml'), { 'spell_data' => {}, 'battle_cries' => {} }.to_yaml)
      File.write(File.join(data_dir, 'base-items.yaml'), {
        'lootables' => [], 'box_nouns' => [], 'gem_nouns' => [], 'scroll_nouns' => []
      }.to_yaml)
    end

    it 'unions arrays for keys listed in union_keys' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[healer moonwatch]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp afk healer moonwatch])
    end

    it 'overwrites arrays for keys NOT listed in union_keys' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'gear' => %w[staff]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp],
        'gear'       => %w[sword shield]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.gear).to eq(%w[staff])
    end

    it 'has no effect when union_keys is not set' do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'autostarts' => %w[esp afk]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[healer]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to eq(%w[healer])
    end

    it 'collects union_keys from multiple files' do
      File.write(File.join(profiles_dir, 'base.yaml'), {
        'union_keys' => ['autostarts'],
        'autostarts' => %w[esp],
        'gear'       => %w[sword]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'include-shared.yaml'), {
        'union_keys' => ['gear'],
        'gear'       => %w[shield]
      }.to_yaml)
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'include'    => ['shared'],
        'autostarts' => %w[healer],
        'gear'       => %w[staff]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp healer])
      expect(settings.gear).to match_array(%w[sword shield staff])
    end

    it 'deduplicates unioned arrays' do
      File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {
        'autostarts' => %w[esp healer]
      }.to_yaml)
      settings = setup_files.get_settings
      expect(settings.autostarts).to match_array(%w[esp afk healer])
      expect(settings.autostarts.length).to eq(3)
    end
  end

  describe '#character_name (private)' do
    it 'prefers Account.character when defined and truthy' do
      stub_const('Lich::Common::Account', double(character: 'Mahtra'))
      expect(setup_files.send(:character_name)).to eq('Mahtra')
    end

    it 'falls back to checkname when Account is not defined' do
      hide_const('Lich::Common::Account')
      allow(setup_files).to receive(:checkname).and_return('FallbackChar')
      expect(setup_files.send(:character_name)).to eq('FallbackChar')
    end

    it 'falls back to checkname when Account.character is nil' do
      stub_const('Lich::Common::Account', double(character: nil))
      allow(setup_files).to receive(:checkname).and_return('FallbackChar')
      expect(setup_files.send(:character_name)).to eq('FallbackChar')
    end

    it 'falls back to checkname when Account.character is false' do
      stub_const('Lich::Common::Account', double(character: false))
      allow(setup_files).to receive(:checkname).and_return('FallbackChar')
      expect(setup_files.send(:character_name)).to eq('FallbackChar')
    end

    it 'uses character_name for profile filenames' do
      stub_const('Lich::Common::Account', double(character: 'Mahtra'))
      File.write(File.join(profiles_dir, 'base.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'base-empty.yaml'), {}.to_yaml)
      File.write(File.join(profiles_dir, 'Mahtra-setup.yaml'), { hometown: 'Shard' }.to_yaml)
      result = setup_files.get_settings
      expect(result.hometown).to eq('Shard')
    end
  end

  describe '#safe_message (private)' do
    it 'delegates to Lich::Messaging.msg when available' do
      expect(Lich::Messaging).to receive(:msg).with('info', 'test message')
      setup_files.send(:safe_message, 'info', 'test message')
    end

    it 'falls back to safe_log when Messaging is not available' do
      hide_const('Lich::Messaging')
      expect(setup_files).to receive(:safe_log).with('test message')
      setup_files.send(:safe_message, 'info', 'test message')
    end
  end

  describe '#safe_log (private)' do
    it 'delegates to Lich.log when available' do
      expect(Lich).to receive(:log).with('test log')
      setup_files.send(:safe_log, 'test log')
    end

    it 'falls back to $stderr when Lich.log is not available' do
      allow(Lich).to receive(:respond_to?).with(:log).and_return(false)
      expect($stderr).to receive(:puts).with('test log')
      setup_files.send(:safe_log, 'test log')
    end
  end
end
