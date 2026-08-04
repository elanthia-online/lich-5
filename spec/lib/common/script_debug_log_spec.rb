# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe 'Lich::Common::ScriptDebugLog' do
  before(:context) do
    # Required explicitly: Script's buffers need it, and relying on another spec
    # file to have loaded it first makes this file order-dependent.
    require_relative '../../../lib/common/limitedarray'
    require_relative '../../../lib/common/script'
  end

  after(:context) do
    Lich::Common::ScriptDebugLog.close_all if Lich::Common.const_defined?(:ScriptDebugLog, false)
    %i[SubScript ExecScript WizardScript Script Scripting TRUSTED_SCRIPT_BINDING].each do |const_name|
      Lich::Common.send(:remove_const, const_name) if Lich::Common.const_defined?(const_name, false)
    end
    $LOADED_FEATURES.delete_if { |path| path.end_with?('/lib/common/script.rb') }
    # ScriptDebugLog is deliberately left loaded: its ScriptDeath handler is
    # registered at load time, and unloading it would leave that handler holding
    # a removed constant for every later spec that triggers script death.
  end

  let(:described_class) { Lich::Common::ScriptDebugLog }
  let(:log_root) { Dir.mktmpdir('lich-debug-log-spec') }

  # A Script with just enough state for the debug log to use: allocate avoids
  # reading a script file off disk or publishing to the running registry.
  def build_script(name, args = [])
    Lich::Common::Script.allocate.tap do |instance|
      instance.instance_variable_set(:@name, name)
      instance.instance_variable_set(:@vars, args)
      instance.instance_variable_set(:@downstream_buffer, Lich::Common::LimitedArray.new)
      instance.instance_variable_set(:@upstream_buffer, Lich::Common::LimitedArray.new)
      instance.instance_variable_set(:@want_downstream, false)
      instance.instance_variable_set(:@want_downstream_xml, false)
      instance.instance_variable_set(:@want_upstream, false)
      instance.instance_variable_set(:@want_script_output, false)
      instance.instance_variable_set(:@watchfor, {})
      allow(instance).to receive(:echo)
    end
  end

  # game/name come from the spec_helper XMLData mock ("rspec" / "testing").
  def script_dir(script_name)
    File.join(log_root, 'debug', 'rspec-testing', script_name)
  end

  # Stream channels are batched, so force them to disk before asserting.
  def contents_of(script)
    Lich::Common::ScriptDebugLog.for(script)&.flush
    File.read(script.debug_log_path)
  end

  before do
    stub_const('LOG_DIR', log_root)
  end

  after do
    described_class.close_all
    described_class.retained_runs = nil
    FileUtils.remove_entry(log_root) if File.directory?(log_root)
  end

  describe 'enabling and disabling' do
    it 'reports inactive until a script opens a log' do
      expect(described_class.active?).to be false
    end

    it 'creates a timestamped file in the per-character, per-script directory' do
      script = build_script('bigshot')

      script.debug_log = true

      expect(File.dirname(script.debug_log_path)).to eq(script_dir('bigshot'))
      expect(File.basename(script.debug_log_path)).to match(/\A\d{8}-\d{6}\.log\z/)
      expect(File.exist?(script.debug_log_path)).to be true
    end

    it 'reports active and answers debug_log? once open' do
      script = build_script('bigshot')

      script.debug_log = true

      expect(described_class.active?).to be true
      expect(script.debug_log?).to be true
    end

    it 'returns no path while logging is off' do
      script = build_script('bigshot')

      expect(script.debug_log_path).to be_nil
      expect(script.debug_log?).to be false
    end

    it 'writes a run header naming the script and character' do
      script = build_script('bigshot', ['debug file'])

      script.debug_log = true

      expect(contents_of(script)).to include('debug log opened')
      expect(contents_of(script)).to include('script: bigshot')
      expect(contents_of(script)).to include('character: testing')
      expect(contents_of(script)).to include('args: debug file')
    end

    it 'is idempotent when enabled twice, keeping the same file' do
      script = build_script('bigshot')

      script.debug_log = true
      first_path = script.debug_log_path
      script.debug_log = true

      expect(script.debug_log_path).to eq(first_path)
      expect(Dir.children(script_dir('bigshot')).length).to eq(1)
    end

    it 'closes and flushes on disable, and goes inactive' do
      script = build_script('bigshot')
      script.debug_log = true
      path = script.debug_log_path

      script.debug_log = false

      expect(script.debug_log?).to be false
      expect(described_class.active?).to be false
      expect(File.read(path)).to include('debug log closed')
    end

    it 'tolerates disable when logging was never enabled' do
      script = build_script('bigshot')

      expect { script.debug_log = false }.not_to raise_error
      expect(script.debug_log?).to be false
    end
  end

  describe 'channel capture' do
    it 'records raw downstream XML through the Script fan-out' do
      script = build_script('bigshot')
      script.debug_log = true

      Lich::Common::Script.new_downstream_xml("<pushBold/>a kobold<popBold/>\r\n")

      expect(contents_of(script)).to match(/XML \s+<pushBold\/>a kobold<popBold\/>/)
    end

    it 'does not log stripped downstream lines, which the XML channel already carries' do
      script = build_script('bigshot')
      script.debug_log = true

      Lich::Common::Script.new_downstream('You see a kobold.')

      expect(contents_of(script)).not_to include('You see a kobold.')
    end

    it 'records client input typed while the script runs' do
      script = build_script('bigshot')
      script.debug_log = true

      Lich::Common::Script.new_upstream('attack kobold')

      expect(contents_of(script)).to match(/YOU \s+attack kobold/)
    end

    it 'records script output, which carries script-issued commands' do
      script = build_script('bigshot')
      script.debug_log = true

      Lich::Common::Script.new_script_output('[bigshot]>attack kobold')

      expect(contents_of(script)).to match(/OUT \s+\[bigshot\]>attack kobold/)
    end

    it 'stamps every entry with a millisecond timestamp' do
      script = build_script('bigshot')
      script.debug_log = true

      Lich::Common::Script.new_downstream_xml('You see a kobold.')

      expect(contents_of(script)).to match(/^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] /)
    end

    it 'ignores blank and nil payloads' do
      script = build_script('bigshot')
      script.debug_log = true
      before_lines = contents_of(script).lines.length

      described_class.broadcast(:downstream_xml, nil)
      described_class.broadcast(:downstream_xml, '')
      described_class.broadcast(:downstream_xml, "\r\n")

      expect(contents_of(script).lines.length).to eq(before_lines)
    end
  end

  describe 'fan-out when no log is open' do
    it 'leaves the existing downstream fan-out behaviour untouched' do
      script = build_script('bigshot')
      script.want_downstream = true
      allow(Lich::Common::Script).to receive(:__running_snapshot).and_return([script])

      Lich::Common::Script.new_downstream('You see a kobold.')

      expect(script.downstream_buffer.to_a).to eq(['You see a kobold.'])
      expect(described_class.active?).to be false
    end

    it 'does not create any log directory' do
      Lich::Common::Script.new_downstream_xml('<prompt/>')
      Lich::Common::Script.new_upstream('north')

      expect(File.directory?(File.join(log_root, 'debug'))).to be false
    end
  end

  describe 'debug_msg' do
    it 'writes to the file when logging is on' do
      script = build_script('bigshot')
      script.debug_log = true

      script.debug_msg('initialize | options: {}')

      expect(contents_of(script)).to match(/MSG \s+initialize \| options: \{\}/)
      expect(script).not_to have_received(:echo)
    end

    it 'echoes to screen when logging is off' do
      script = build_script('bigshot')

      script.debug_msg('initialize | options: {}')

      expect(script).to have_received(:echo).with('initialize | options: {}')
    end

    it 'drops the message when to_screen is false and no log is open' do
      script = build_script('eloot')

      script.debug_msg('handled by the script itself', to_screen: false)

      expect(script).not_to have_received(:echo)
    end

    it 'still writes to the file when to_screen is false and a log is open' do
      script = build_script('eloot')
      script.debug_log = true

      script.debug_msg('handled by the script itself', to_screen: false)

      expect(contents_of(script)).to include('handled by the script itself')
      expect(script).not_to have_received(:echo)
    end

    it 'reports the destination directory even while logging is off' do
      script = build_script('bigshot')

      expect(script.debug_log_dir).to eq(script_dir('bigshot'))
      expect(script.debug_log_path).to be_nil
    end

    it 'reports a directory that matches where an opened log lands' do
      script = build_script('bigshot')
      directory = script.debug_log_dir

      script.debug_log = true

      expect(File.dirname(script.debug_log_path)).to eq(directory)
    end

    it 'flushes immediately so the message is readable without closing' do
      script = build_script('bigshot')
      script.debug_log = true

      script.debug_msg('checkpoint reached')

      expect(File.read(script.debug_log_path)).to include('checkpoint reached')
    end
  end

  describe 'multiple scripts logging at once' do
    it 'gives each script its own file with no shared hook names to collide' do
      bigshot = build_script('bigshot')
      eloot = build_script('eloot')

      bigshot.debug_log = true
      eloot.debug_log = true
      Lich::Common::Script.new_downstream_xml('You see a kobold.')

      expect(bigshot.debug_log_path).not_to eq(eloot.debug_log_path)
      expect(contents_of(bigshot)).to include('You see a kobold.')
      expect(contents_of(eloot)).to include('You see a kobold.')
    end

    it 'keeps the survivor logging when the other script closes' do
      bigshot = build_script('bigshot')
      eloot = build_script('eloot')
      bigshot.debug_log = true
      eloot.debug_log = true

      eloot.debug_log = false
      Lich::Common::Script.new_downstream_xml('You see a rolton.')

      expect(bigshot.debug_log?).to be true
      expect(contents_of(bigshot)).to include('You see a rolton.')
      expect(described_class.active?).to be true
    end
  end

  describe 'teardown on script death' do
    it 'closes the log from the ScriptDeath handler' do
      script = build_script('bigshot')
      script.debug_log = true
      path = script.debug_log_path

      Lich::Common::ScriptDeath.run(script)

      expect(script.debug_log?).to be false
      expect(described_class.active?).to be false
      expect(File.read(path)).to include('debug log closed')
    end

    it 'captures anything logged before death, since handlers run after at_exit' do
      script = build_script('bigshot')
      script.debug_log = true
      path = script.debug_log_path

      script.debug_msg('before_dying ran')
      Lich::Common::ScriptDeath.run(script)

      expect(File.read(path)).to include('before_dying ran')
    end
  end

  describe 'retention' do
    it 'prunes old runs down to the retained-file limit' do
      allow(described_class).to receive(:retained_runs).and_return(3)
      directory = script_dir('bigshot')
      FileUtils.mkdir_p(directory)
      %w[20200101-000001.log 20200101-000002.log 20200101-000003.log 20200101-000004.log].each do |name|
        File.write(File.join(directory, name), 'old')
      end

      build_script('bigshot').debug_log = true

      expect(Dir.children(directory).length).to eq(3)
    end

    it 'keeps the newest runs and deletes the oldest' do
      allow(described_class).to receive(:retained_runs).and_return(2)
      directory = script_dir('bigshot')
      FileUtils.mkdir_p(directory)
      %w[20200101-000001.log 20200101-000009.log].each do |name|
        File.write(File.join(directory, name), 'old')
      end

      build_script('bigshot').debug_log = true

      expect(Dir.children(directory)).to include('20200101-000009.log')
      expect(Dir.children(directory)).not_to include('20200101-000001.log')
    end

    it 'defaults to DEFAULT_RETAINED_RUNS' do
      expect(described_class.retained_runs).to eq(Lich::Common::ScriptDebugLog::DEFAULT_RETAINED_RUNS)
    end

    it 'honours a process-wide override' do
      described_class.retained_runs = 5

      expect(described_class.retained_runs).to eq(5)
    end

    it 'falls back to the default for a nonsense override' do
      described_class.retained_runs = 0

      expect(described_class.retained_runs).to eq(Lich::Common::ScriptDebugLog::DEFAULT_RETAINED_RUNS)
    end

    it 'does not consult Lich debug log retention, which governs Lich internals' do
      expect(Lich).not_to receive(:max_debug_logs)

      build_script('bigshot').debug_log = true

      expect(described_class.retained_runs).to eq(Lich::Common::ScriptDebugLog::DEFAULT_RETAINED_RUNS)
    end

    it 'leaves unrelated files in the directory alone' do
      allow(described_class).to receive(:retained_runs).and_return(1)
      directory = script_dir('bigshot')
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, 'notes.txt'), 'keep me')

      build_script('bigshot').debug_log = true

      expect(Dir.children(directory)).to include('notes.txt')
    end
  end

  describe 'path safety' do
    it 'flattens path separators in custom script names into one segment' do
      script = build_script('custom/mytest')

      script.debug_log = true

      expect(File.dirname(script.debug_log_path)).to eq(script_dir('custom_mytest'))
    end
  end

  describe 'write failures' do
    it 'closes the log and reports instead of raising into the game stream' do
      allow(described_class).to receive(:__report)
      script = build_script('bigshot')
      script.debug_log = true
      writer = described_class.for(script)
      writer.instance_variable_get(:@io).close

      expect { Lich::Common::Script.new_downstream_xml('You see a kobold.') }.not_to raise_error
      expect(writer.open?).to be false
    end
  end
end
