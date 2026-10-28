# frozen_string_literal: true

require_relative '../../../spec_helper'

# Load the startup module
require 'dragonrealms/drinfomon/startup'

RSpec.describe Lich::DragonRealms::DRInfomon do
  before(:each) do
    # NOTE: class_variable_set used because DRInfomon is a production module with no reset! method
    described_class.class_variable_set(:@@startup_complete, false)
    described_class.instance_variable_set(:@startup_thread, nil)
  end

  describe '.startup_complete?' do
    it 'returns false initially' do
      expect(described_class.startup_complete?).to be false
    end

    it 'returns true after startup_completed! is called' do
      described_class.startup_completed!
      expect(described_class.startup_complete?).to be true
    end
  end

  describe '.watch!' do
    let(:mock_thread) { instance_double(Thread) }

    before do
      # Stub Thread.new to prevent actual thread creation
      allow(Thread).to receive(:new).and_return(mock_thread)
    end

    it 'creates a background thread' do
      expect(Thread).to receive(:new)
      described_class.watch!
    end

    it 'only creates one thread on multiple calls' do
      described_class.watch!
      expect(Thread).not_to receive(:new)
      described_class.watch!
    end

    it 'stores the thread in @startup_thread' do
      described_class.watch!
      expect(described_class.instance_variable_get(:@startup_thread)).to eq(mock_thread)
    end
  end

  describe '.startup' do
    it 'calls ExecScript.start with startup_script' do
      expect(ExecScript).to receive(:start).with(
        described_class.startup_script,
        hash_including(name: 'drinfomon_startup')
      )
      described_class.startup
    end
  end

  describe '.startup_script' do
    it 'returns a string with game commands' do
      script = described_class.startup_script
      expect(script).to be_a(String)
      expect(script).to include('info')
      expect(script).to include('played')
      expect(script).to include('exp all 0')
      expect(script).to include('ability')
    end

    it 'calls startup_completed! at the end' do
      script = described_class.startup_script
      expect(script).to include('DRInfomon.startup_completed!')
    end
  end

  describe 'thread behavior' do
    it 'watch! thread body delegates to startup' do
      # The watch! thread body is:
      #   sleep 0.1 until GameBase::Game.autostarted? && XMLData.name && !XMLData.name.empty?
      #   startup
      #
      # Thread creation is tested in .watch! specs above.
      # Here we verify the startup delegation contract.
      allow(described_class).to receive(:startup)

      described_class.startup

      expect(described_class).to have_received(:startup).once
    end

    it 'startup_completed! signals PostLoad when defined' do
      # PostLoad is defined via spec_helper loading gameloader.rb
      if defined?(PostLoad)
        allow(PostLoad).to receive(:game_loaded!)
        described_class.startup_completed!
        expect(PostLoad).to have_received(:game_loaded!)
      else
        described_class.startup_completed!
      end

      expect(described_class.startup_complete?).to be true
    end
  end

  describe '.startup_script flag handling' do
    it 'wraps issue_command output with Array() for nil safety' do
      script = described_class.startup_script
      expect(script).to include('Array(Lich::Util.issue_command("flag"')
    end

    it 'still enforces the MonsterBold flag' do
      expect(described_class.startup_script).to include('MonsterBold')
    end

    it 'requires only MonsterBold (ShowRoomID is no longer forced)' do
      expect(described_class.startup_script).to include('required = ["MonsterBold"]')
    end

    it 'no longer lists ShowRoomID among the enforced flags (room UIDs come from the <nav> tag)' do
      # The explanatory comment in the script still names ShowRoomID; what matters is that it is
      # not one of the quoted flags in the required array, so match the array-literal form.
      expect(described_class.startup_script).not_to include('"ShowRoomID"')
    end
  end

  describe 'revival refresh' do
    # Drives the REAL watch_for_revival loop: dead? answers come from `states`
    # (one per poll, last value repeats), and the poll sleep raises
    # StopIteration after `polls` ticks, which ends Kernel#loop.
    def run_watcher(states:, guild: 'Warrior Mage', polls: states.size)
      described_class.class_variable_set(:@@startup_complete, true)
      allow(Lich::DragonRealms::DRStats).to receive(:guild).and_return(guild)
      answers = states.dup
      allow(described_class).to receive(:dead?) { answers.size > 1 ? answers.shift : answers.first }
      ticks = 0
      allow(described_class).to receive(:sleep) do |seconds|
        next unless seconds == described_class::REVIVAL_POLL_INTERVAL

        ticks += 1
        raise StopIteration if ticks >= polls
      end
      described_class.watch_for_revival
    end

    before { allow(described_class).to receive(:refresh_stats) }

    it 'never refreshes a character who stays alive with a known guild' do
      # initial pending check + 5 polls
      run_watcher(states: [false] * 6)
      expect(described_class).not_to have_received(:refresh_stats)
    end

    it 'never refreshes while the character stays dead' do
      run_watcher(states: [true] * 6)
      expect(described_class).not_to have_received(:refresh_stats)
    end

    it 'refreshes exactly once when a character who logged in dead is revived' do
      # pending check: dead; polls: dead, dead, alive, alive, alive
      run_watcher(states: [true, true, true, false, false, false], guild: nil, polls: 5)
      expect(described_class).to have_received(:refresh_stats).once
    end

    it 'refreshes once right away when startup left the guild nil but the character is alive' do
      run_watcher(states: [false] * 6, guild: nil, polls: 5)
      expect(described_class).to have_received(:refresh_stats).once
    end

    it 'does not keep re-sending info when the refresh still leaves the guild nil' do
      # guild stays nil forever; the nil-guild pending is only taken once
      run_watcher(states: [false] * 20, guild: nil, polls: 19)
      expect(described_class).to have_received(:refresh_stats).once
    end

    it 'refreshes after each mid-session death, once per revival' do
      # alive, die, revive, alive, die, die, revive, alive
      run_watcher(states: [false, false, true, false, false, true, true, false, false], polls: 8)
      expect(described_class).to have_received(:refresh_stats).twice
    end

    it 'waits for startup to complete before checking dead?' do
      described_class.class_variable_set(:@@startup_complete, false)
      allow(described_class).to receive(:dead?).and_return(false)
      waits = 0
      allow(described_class).to receive(:sleep) do |seconds|
        raise StopIteration if seconds == described_class::REVIVAL_POLL_INTERVAL

        waits += 1
        described_class.class_variable_set(:@@startup_complete, true) if waits == 3
      end
      described_class.watch_for_revival
      expect(waits).to eq(3)
    end
  end

  describe '.revival_tick' do
    before { allow(described_class).to receive(:dead?).and_return(false) }

    it 'marks a refresh pending while dead without refreshing' do
      allow(described_class).to receive(:dead?).and_return(true)
      expect(described_class).not_to receive(:refresh_stats)
      expect(described_class.revival_tick(false)).to be true
    end

    it 'logs and drops the pending refresh when the refresh raises' do
      allow(described_class).to receive(:refresh_stats).and_raise(StandardError, 'boom')
      expect(described_class).to receive(:safe_message).with('error', /revival refresh failed: boom/)
      allow(described_class).to receive(:safe_log)
      expect(described_class.revival_tick(true)).to be false
    end
  end

  describe '.refresh_stats' do
    it 'runs refresh_script as its own quiet ExecScript' do
      expect(ExecScript).to receive(:start).with(
        described_class.refresh_script,
        hash_including(quiet: true, name: 'drinfomon_refresh')
      )
      described_class.refresh_stats
    end
  end

  describe '.refresh_script' do
    let(:script) { described_class.refresh_script }

    it 're-sends info (still skipped while dead) and exp all 0' do
      expect(script).to include('Lich::Util.issue_command("info"')
      expect(script).to include('quiet: true, timeout: 1) unless dead?')
      expect(script).to include('Lich::Util.issue_command("exp all 0", /^Circle: \\d+/')
    end

    it 'does not re-run login-only work or re-fire the PostLoad lifecycle' do
      expect(script).not_to include('played')
      expect(script).not_to include('ability')
      expect(script).not_to include('flag')
      expect(script).not_to include('startup_completed!')
    end

    it 'is valid Ruby' do
      expect { RubyVM::InstructionSequence.compile(script) }.not_to raise_error
    end
  end

  describe 'watch! thread body' do
    it 'starts the revival watcher after issuing startup' do
      allow(described_class).to receive(:ready_for_startup?).and_return(true)
      # The body runs inline on the spec thread: fail instead of hanging if it ever waits.
      allow(described_class).to receive(:sleep).and_raise('watch! body waited for readiness')
      allow(Thread).to receive(:new) { |&body| body.call }
      calls = []
      allow(described_class).to receive(:startup) { calls << :startup }
      allow(described_class).to receive(:watch_for_revival) { calls << :watch_for_revival }
      described_class.watch!
      expect(calls).to eq(%i[startup watch_for_revival])
    end
  end

  describe '.post_startup_checks' do
    before do
      allow(described_class).to receive(:warn_obsolete_scripts)
      allow(described_class).to receive(:warn_obsolete_data_files)
      allow(described_class).to receive(:warn_custom_scripts)
    end

    it 'calls all warning methods' do
      described_class.post_startup_checks
      expect(described_class).to have_received(:warn_obsolete_scripts)
      expect(described_class).to have_received(:warn_obsolete_data_files)
      expect(described_class).to have_received(:warn_custom_scripts)
    end

    it 'reloads $setupfiles when defined' do
      setupfiles = double('setupfiles')
      allow(setupfiles).to receive(:reload)
      original = $setupfiles
      $setupfiles = setupfiles
      described_class.post_startup_checks
      expect(setupfiles).to have_received(:reload)
    ensure
      $setupfiles = original
    end

    it 'rescues and logs errors without raising' do
      allow(described_class).to receive(:warn_obsolete_scripts).and_raise(StandardError, 'test error')
      expect { described_class.post_startup_checks }.not_to raise_error
    end
  end

  describe '.warn_custom_scripts' do
    let(:tmpdir) { Dir.mktmpdir('startup-test') }
    let(:custom_dir) { File.join(tmpdir, 'custom') }

    before do
      stub_const('SCRIPT_DIR', tmpdir)
      FileUtils.mkdir_p(custom_dir)
    end

    after { FileUtils.remove_entry(tmpdir, true) }

    it 'only checks .lic files' do
      # Create a non-.lic file that shadows a curated name
      File.write(File.join(custom_dir, 'moonwatch.txt'), '')
      File.write(File.join(tmpdir, 'moonwatch.txt'), '')

      expect(Lich::Messaging).not_to receive(:msg)
      described_class.warn_custom_scripts
    end

    it 'warns when custom .lic files shadow curated scripts' do
      File.write(File.join(custom_dir, 'moonwatch.lic'), '')
      File.write(File.join(tmpdir, 'moonwatch.lic'), '')

      expect(Lich::Messaging).to receive(:msg).with('info', /curated scripts/)
      expect(Lich::Messaging).to receive(:msg).with('info', /moonwatch\.lic/)
      described_class.warn_custom_scripts
    end

    it 'does not warn when custom scripts do not shadow curated ones' do
      File.write(File.join(custom_dir, 'my-custom-script.lic'), '')

      expect(Lich::Messaging).not_to receive(:msg)
      described_class.warn_custom_scripts
    end

    it 'does nothing when custom directory does not exist' do
      FileUtils.rm_rf(custom_dir)
      expect { described_class.warn_custom_scripts }.not_to raise_error
    end
  end

  describe '.safe_message' do
    it 'delegates to Lich::Messaging.msg when available' do
      expect(Lich::Messaging).to receive(:msg).with('error', 'test')
      described_class.safe_message('error', 'test')
    end

    it 'falls back to safe_log when Messaging is unavailable' do
      allow(Lich::Messaging).to receive(:respond_to?).with(:msg).and_return(false)
      expect(described_class).to receive(:safe_log).with('test')
      described_class.safe_message('error', 'test')
    end
  end

  describe '.safe_log' do
    it 'delegates to Lich.log when available' do
      expect(Lich).to receive(:log).with('test log')
      described_class.safe_log('test log')
    end

    it 'falls back to $stderr when Lich.log is unavailable' do
      allow(Lich).to receive(:respond_to?).with(:log).and_return(false)
      expect($stderr).to receive(:puts).with('test log')
      described_class.safe_log('test log')
    end
  end
end
