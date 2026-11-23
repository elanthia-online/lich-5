# frozen_string_literal: true

require_relative '../../spec_helper'
require 'common/settings_transformer'
require 'common/setup_files'
require 'common/class_exts/synchronizedsocket'
require 'socket'

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

      # Pins the message from the original report, which the flaky helper
      # cannot produce on current Ruby; guards the matcher against narrowing.
      it 'retries the reported "hash representation was changed" error' do
        dumps = 0
        allow(Marshal).to receive(:dump).and_wrap_original do |original, *args|
          dumps += 1
          raise RuntimeError, 'hash representation was changed during iteration' if dumps == 1

          original.call(*args)
        end

        copy = file_info_with({ setting: 'value' }).data

        expect(copy).to eq({ setting: 'value' })
        expect(dumps).to eq(2)
      end

      it 'yields to other threads before each retry' do
        allow(Thread).to receive(:pass)
        flaky = FlakyDump.new(2)
        data = { flaky: flaky }
        flaky.parent = data

        file_info_with(data).data

        expect(Thread).to have_received(:pass).twice
      end

      it 'falls back to $stderr for the retry log when Lich.log is unavailable' do
        allow(Lich).to receive(:respond_to?).and_call_original
        allow(Lich).to receive(:respond_to?).with(:log).and_return(false)
        flaky = FlakyDump.new(1)
        data = { flaky: flaky }
        flaky.parent = data

        expect { file_info_with(data).data }
          .to output(/retrying deep copy of \/tmp\/flaky\.yaml \(attempt 1\)/).to_stderr
        expect(Lich).not_to have_received(:log)
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
      allow(setup_files).to receive(:parse_yaml_file).and_wrap_original do |original, filepath|
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
      allow(setup_files).to receive(:parse_yaml_file).and_wrap_original do |original, filepath|
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

    # Public return value kept as it was before the interrupt-safety change,
    # for external scripts: the data scan's basename => winning path map.
    it 'returns the data files it found, with scripts/data/custom winning' do
      FileUtils.mkdir_p(custom_data_dir)
      File.write(File.join(data_dir, 'base-town.yaml'), {}.to_yaml)
      File.write(File.join(data_dir, 'base-spells.yaml'), {}.to_yaml)
      File.write(File.join(custom_data_dir, 'base-town.yaml'), {}.to_yaml)

      expect(setup_files.reload).to eq(
        'base-town.yaml'   => File.join(custom_data_dir, 'base-town.yaml'),
        'base-spells.yaml' => File.join(data_dir, 'base-spells.yaml')
      )
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
      # Spy on the cache's parser to verify the file is not parsed again
      expect(setup_files).not_to receive(:parse_yaml_file).with(File.join(profiles_dir, 'base.yaml'))
      setup_files.get_settings
    end
  end

  # A load that fails is retried on the next scan instead of being cached as {}
  # until the file changes (issue #2485). Its error is reported once per file
  # content and error, so a file that stays malformed is not reported on
  # every retry.
  describe 'failed loads' do
    let(:setup_path) { File.join(profiles_dir, 'TestChar-setup.yaml') }
    let(:reports) { [] }

    before do
      File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
      File.write(setup_path, { hometown: 'Crossing' }.to_yaml)
      allow(Lich::Messaging).to receive(:msg) { |_type, text| reports << text }
    end

    def parse_error_reports
      reports.count('*** ERROR PARSING YAML FILE ***')
    end

    # Makes the next `times` reads of TestChar-setup.yaml raise `error`.
    def fail_setup_reads(error, times: 1)
      remaining = times
      allow(File).to receive(:read).and_wrap_original do |original, path, *args, **kwargs|
        if path.to_s == setup_path && remaining.positive?
          remaining -= 1
          raise error
        end
        original.call(path, *args, **kwargs)
      end
    end

    it 'reloads a file whose parse was interrupted by Thread#raise' do
      entered = Queue.new
      release = Queue.new
      blocked = false
      allow(YAML).to receive(:unsafe_load).and_wrap_original do |original, content, **kwargs|
        if !blocked && kwargs[:filename] == setup_path
          blocked = true
          entered << :parsing
          release.pop
        end
        original.call(content, **kwargs)
      end
      thread = Thread.new { setup_files.reload }
      thread.report_on_exception = false
      expect(entered.pop(timeout: 5)).to eq(:parsing)
      thread.raise(RuntimeError, 'stop requested')
      release << :go
      expect(thread.join(5)).to eq(thread)

      expect(setup_files.get_settings.hometown).to eq('Crossing')
    end

    it 'reloads a file after a transient read error' do
      fail_setup_reads(Errno::EMFILE.new(setup_path))
      expect(setup_files.get_settings.hometown).to be_nil
      expect(reports).to include(a_string_matching(/Too many open files/))

      expect(setup_files.get_settings.hometown).to eq('Crossing')
    end

    it 'serves an empty profile while the file stays malformed' do
      File.write(setup_path, "hometown: [Crossing\n")
      2.times { expect(setup_files.get_settings.hometown).to be_nil }
    end

    it 'reports a file that stays malformed once, not on every scan' do
      File.write(setup_path, "hometown: [Crossing\n")
      3.times { setup_files.get_settings }
      expect(parse_error_reports).to eq(1)
    end

    it 'reports again when the malformed file is edited and still malformed' do
      File.write(setup_path, "hometown: [Crossing\n")
      setup_files.get_settings
      File.write(setup_path, "hometown: [Shard\n")
      setup_files.get_settings
      expect(parse_error_reports).to eq(2)
    end

    it 'reports again when a removed malformed file is restored' do
      File.write(setup_path, "hometown: [Crossing\n")
      setup_files.get_settings
      File.delete(setup_path)
      setup_files.get_settings
      File.write(setup_path, "hometown: [Crossing\n")
      setup_files.get_settings
      expect(parse_error_reports).to eq(2)
    end

    it 'reports a recurring error again after the file has loaded in between' do
      fail_setup_reads(Errno::EMFILE.new(setup_path))
      setup_files.get_settings # fails: reported
      setup_files.get_settings # retried: loads Crossing, clearing the error
      File.write(setup_path, { hometown: 'Shard' }.to_yaml)
      setup_files.get_settings
      File.write(setup_path, { hometown: 'Crossing' }.to_yaml) # same content as the first failure
      fail_setup_reads(Errno::EMFILE.new(setup_path))
      setup_files.get_settings # same content, same error: reported again
      expect(parse_error_reports).to eq(2)
      expect(setup_files.get_settings.hometown).to eq('Crossing')
    end

    it 'keeps #safe_load_yaml reporting on every call' do
      File.write(setup_path, "hometown: [Crossing\n")
      2.times { expect(setup_files.safe_load_yaml(setup_path)).to eq({}) }
      expect(parse_error_reports).to eq(2)
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

  # Script#kill stops a script's threads with Thread#kill. On Ruby 4.0 a thread
  # killed inside Dir.glob or File.open can leak the descriptor: no Ruby object
  # owns it yet, so GC never closes it. A character whose loop stopped a script
  # while it was still loading its settings leaked one scripts/profiles handle
  # per stop, about 1,000 in four hours, until the process hit its open-files
  # limit (1024) and every script start failed with "Too many open files".
  # #load_files defers interrupts around each descriptor-opening call, and only
  # there: a thread started under the deferral inherits it and cannot be killed.
  describe 'interrupt safety of #load_files (private)' do
    let(:entered) { Queue.new }
    let(:release) { Queue.new }
    let(:loader_threads) { [] }

    # Starts a background thread the way a script runs: exceptions surface
    # through #value / #join instead of being printed.
    def spawn_loader(&block)
      thread = Thread.new(&block)
      thread.report_on_exception = false
      loader_threads << thread
      thread
    end

    # Makes the first Dir.glob of the profiles scan block until the spec pushes
    # to `release`, and reports it on `entered`. Later globs pass through.
    def block_profiles_glob
      blocked = false
      allow(Dir).to receive(:glob).and_wrap_original do |original, pattern, *args, **kwargs|
        if !blocked && pattern.to_s.start_with?(profiles_dir)
          blocked = true
          entered << pattern
          release.pop
        end
        original.call(pattern, *args, **kwargs)
      end
    end

    # Makes the File.read of `filename` block the same way.
    def block_file_read(filename)
      allow(File).to receive(:read).and_wrap_original do |original, path, *args, **kwargs|
        if File.basename(path.to_s) == filename
          entered << path
          release.pop
        end
        original.call(path, *args, **kwargs)
      end
    end

    def wait_until_entered
      expect(entered.pop(timeout: 5)).not_to be_nil, 'loader thread never reached the blocked call'
    end

    def wait_until_sleeping(thread)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      sleep 0.001 until thread.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      expect(thread.status).to eq('sleep')
    end

    def expect_finished(thread)
      expect(thread.join(5)).to eq(thread), 'thread did not finish within 5 s'
    end

    def cached_entries
      setup_files.instance_variable_get(:@files_cache)
    end

    after do
      release.close
      loader_threads.each do |thread|
        thread.kill
        begin
          thread.join(5)
        rescue StandardError
          nil # a deferred Thread#raise surfaces here; the example already checked it
        end
      end
    end

    context 'with an interrupt that arrives inside Dir.glob' do
      before do
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { hometown: 'Crossing' }.to_yaml)
        block_profiles_glob
      end

      it 'defers Thread#kill until Dir.glob returns' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered

        thread.kill
        expect(thread.join(0.2)).to be_nil
        expect(thread).to be_alive

        release << :go
        expect_finished(thread)
        expect(thread).not_to be_alive
      end

      it 'stops as soon as Dir.glob returns, before loading anything or scanning further' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered
        thread.kill
        release << :go
        expect_finished(thread)

        expect(cached_entries).to be_empty
        expect(Dir).not_to have_received(:glob).with(start_with(data_dir))
      end

      it 'defers Thread#raise too, then raises it once Dir.glob returns' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered

        thread.raise(RuntimeError, 'stop requested')
        expect(thread.join(0.2)).to be_nil

        release << :go
        expect { thread.join(5) }.to raise_error(RuntimeError, 'stop requested')
        expect(thread).not_to be_alive
      end

      it 'releases the monitor when the deferred kill fires' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered
        thread.kill
        release << :go
        expect_finished(thread)

        expect(setup_files.mon_locked?).to be(false)
        other = spawn_loader { setup_files.synchronize { :entered } }
        expect_finished(other)
        expect(other.value).to eq(:entered)
      end

      it 'holds back each kill sent during the call, not just the first' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered

        3.times do
          thread.kill
          expect(thread.join(0.05)).to be_nil
        end

        release << :go
        expect_finished(thread)
      end
    end

    context 'with an interrupt that arrives inside a file read' do
      before do
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { hometown: 'Crossing' }.to_yaml)
        block_file_read('TestChar-setup.yaml')
      end

      it 'defers the kill until the read returns, keeping only complete entries' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered
        thread.kill
        expect(thread.join(0.2)).to be_nil

        release << :go
        expect_finished(thread)

        expect(cached_entries.keys).to eq(['base.yaml'])
        cached_entries.each_value do |info|
          expect(info.digest).to eq(Digest::SHA256.file(File.join(info.path, info.name)).hexdigest)
        end
      end

      it 'lets the next reload pick up the files the killed one did not reach' do
        thread = spawn_loader { setup_files.reload }
        wait_until_entered
        thread.kill
        release << :go
        expect_finished(thread)

        release << :go # the next reload reads TestChar-setup.yaml again
        expect(spawn_loader { setup_files.get_settings.hometown }.tap { |t| expect_finished(t) }.value)
          .to eq('Crossing')
      end
    end

    context 'with an interrupt that arrives outside the guarded calls' do
      it 'still kills a thread waiting for the monitor' do
        block_profiles_glob
        setup_files.mon_enter
        begin
          thread = spawn_loader { setup_files.reload }
          wait_until_sleeping(thread)

          thread.kill
          expect_finished(thread)
          expect(entered).to be_empty
        ensure
          setup_files.mon_exit
        end
      end

      it 'kills a thread at once while it reports a malformed file' do
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), "hometown: [Crossing\n")
        allow(Lich::Messaging).to receive(:msg) do
          entered << :reporting
          release.pop
        end

        thread = spawn_loader { setup_files.reload }
        wait_until_entered
        thread.kill
        expect_finished(thread)
      end

      it 'restores immediate interrupts once #load_files returns' do
        ready = Queue.new
        thread = spawn_loader do
          setup_files.reload
          ready << :loaded
          sleep
        end
        expect(ready.pop(timeout: 5)).to eq(:loaded)

        thread.kill
        expect_finished(thread)
      end
    end

    # The first message to a newly attached client starts the socket's writer
    # thread. When that message was a YAML error raised inside the deferral,
    # the writer inherited it and the script's group, so Script#kill's cleanup
    # waited on a writer it could never kill.
    context 'with a malformed file whose error message starts a client socket writer' do
      let(:peer_pair) { UNIXSocket.pair }
      let(:client) { Lich::Common::SynchronizedSocket.new(peer_pair[0]) }
      let(:peer) { peer_pair[1] }

      before do
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), "hometown: [Crossing\n")
        allow(Lich::Messaging).to receive(:msg) { |_type, text| client.puts(text) }
      end

      after do
        client.close
        peer.close
      end

      def read_peer_until(text)
        received = +''
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        until received.include?(text) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          received << peer.read_nonblock(4096) if peer.wait_readable(0.05)
        end
        received
      end

      # Runs the reload on a thread in its own group, the way a script runs,
      # then kills every thread in the group and waits for each, the way
      # Script#kill's cleanup does.
      def run_and_kill_script
        group = ThreadGroup.new
        gate = Queue.new
        loaded = Queue.new
        script = spawn_loader do
          gate.pop
          setup_files.reload
          loaded << :done
          sleep
        end
        group.add(script)
        gate << :go
        expect(loaded.pop(timeout: 5)).to eq(:done)
        workers = group.list
        workers.each(&:kill)
        workers.each { |worker| expect_finished(worker) }
      end

      it 'lets script teardown finish while the client stays connected' do
        run_and_kill_script
        expect(client).to be_alive
      end

      it 'still delivers the error and fresh output to the client after teardown' do
        run_and_kill_script
        client.puts('fresh output')
        received = read_peer_until('fresh output')
        expect(received).to include('*** ERROR PARSING YAML FILE ***')
        expect(received).to include('fresh output')
      end
    end

    context 'with errors raised by the scan itself' do
      it 'still propagates a Dir.glob failure to the caller' do
        allow(Dir).to receive(:glob).and_raise(Errno::EACCES, profiles_dir)
        expect { setup_files.reload }.to raise_error(Errno::EACCES)
        expect(setup_files.mon_locked?).to be(false)
      end

      it 'still loads files normally when nothing interrupts it' do
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 3 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
        thread = spawn_loader { setup_files.get_settings.version }
        expect_finished(thread)
        expect(thread.value).to eq(3)
      end

      it 'still reads a file that starts with a UTF-8 byte order mark' do
        File.binwrite(File.join(profiles_dir, 'base.yaml'), [0xEF, 0xBB, 0xBF].pack('C*') + "version: 4\n")
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), {}.to_yaml)
        expect(setup_files.get_settings.version).to eq(4)
      end
    end

    # These run the real Dir.glob and File.open against a real directory and
    # count this process's open descriptors. Without the deferral almost every
    # kill leaks one descriptor, so a few hundred kills fail by a wide margin.
    context 'with real descriptors', if: %w[/dev/fd /proc/self/fd].any? { |dir| File.directory?(dir) } do
      let(:fd_dir) { %w[/proc/self/fd /dev/fd].find { |dir| File.directory?(dir) } }
      let(:kills) { 300 }

      def open_descriptors
        Dir.children(fd_dir).size
      end

      # The count to compare against after the kills. GC first, so a File that
      # an earlier spec left unclosed is finalized now rather than during the
      # kills, where it would lower the final count. GC cannot hide the leak
      # under test: a descriptor leaked inside Dir.glob or File.open has no
      # Ruby object, so GC never closes it.
      def descriptor_baseline
        GC.start
        open_descriptors
      end

      # Counts, per thread, the real Dir.glob calls it has started.
      def count_globs
        allow(Dir).to receive(:glob).and_wrap_original do |original, *args, **kwargs|
          Thread.current[:globs] = Thread.current[:globs].to_i + 1
          original.call(*args, **kwargs)
        end
      end

      # Kills `kills` loader threads at random points inside a busy loop of
      # `work`, each only after it has started a real scan, and returns how
      # many had. `between` runs on the spec's own thread before each loader
      # starts, so its file I/O is never killed.
      def kill_loaders_repeatedly(between: nil, &work)
        Array.new(kills) do
          between&.call
          thread = spawn_loader { loop(&work) }
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
          sleep 0.0001 until thread[:globs].to_i.positive? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep(rand * 0.002)
          scanning = thread.alive? && thread[:globs].to_i.positive?
          thread.kill
          expect_finished(thread)
          scanning
        end.count(true)
      end

      # Hundreds of unrelated files make each scan read a large directory, the
      # way a shared scripts/profiles directory does, widening the window.
      before do
        300.times { |i| FileUtils.touch(File.join(profiles_dir, "Other#{i}-setup.yaml")) }
        File.write(File.join(profiles_dir, 'base.yaml'), { version: 1 }.to_yaml)
        File.write(File.join(profiles_dir, 'TestChar-setup.yaml'), { hometown: 'Crossing' }.to_yaml)
        File.write(File.join(data_dir, 'base-town.yaml'), { town: { 'Crossing' => { 'id' => 1 } } }.to_yaml)
        setup_files.reload # warm the cache so later passes are steady-state
        count_globs
      end

      it 'does not leak a descriptor when threads running #get_settings are killed' do
        before_count = descriptor_baseline
        expect(kill_loaders_repeatedly { setup_files.get_settings }).to eq(kills)
        expect(open_descriptors).to eq(before_count)
      end

      it 'does not leak a descriptor when threads running #get_data are killed' do
        before_count = descriptor_baseline
        expect(kill_loaders_repeatedly { setup_files.get_data('town') }).to eq(kills)
        expect(open_descriptors).to eq(before_count)
      end

      it 'does not leak a descriptor when threads running #reload are killed' do
        before_count = descriptor_baseline
        expect(kill_loaders_repeatedly { setup_files.reload }).to eq(kills)
        expect(open_descriptors).to eq(before_count)
      end

      it 'does not leak a descriptor when a changed file is reloaded as threads are killed' do
        base = File.join(profiles_dir, 'base.yaml')
        before_count = descriptor_baseline
        rewrite = -> { File.write(base, { version: rand(1_000_000) }.to_yaml) }
        killed = kill_loaders_repeatedly(between: rewrite) { setup_files.reload }
        expect(killed).to eq(kills)
        expect(open_descriptors).to eq(before_count)
      end

      it 'keeps the monitor free after hundreds of kills' do
        expect(kill_loaders_repeatedly { setup_files.reload }).to eq(kills)
        expect(setup_files.mon_locked?).to be(false)
        expect(setup_files.get_settings.version).to eq(1)
      end
    end
  end
end
