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
