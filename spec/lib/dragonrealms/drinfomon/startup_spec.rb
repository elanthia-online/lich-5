# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lich::DragonRealms::DRInfomon do
  describe '.startup_complete?' do
    it 'returns false initially' do
      # Reset the class variable
      described_class.class_variable_set(:@@startup_complete, false)
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
      # Reset the instance variable
      described_class.instance_variable_set(:@startup_thread, nil)
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
      skip 'Requires ExecScript to be defined'
      # This would need ExecScript to be loaded
      # expect(ExecScript).to receive(:start).with(anything, hash_including(name: "drinfomon_startup"))
      # described_class.startup
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

  describe 'thread behavior', :integration do
    it 'waits for autostarted? to be true' do
      # Reset state
      described_class.instance_variable_set(:@startup_thread, nil)
      described_class.class_variable_set(:@@startup_complete, false)

      startup_called = false
      autostarted = false
      character_name = nil

      # Mock GameBase::Game.autostarted? to reference our variable
      allow(GameBase::Game).to receive(:autostarted?) { autostarted }

      # Mock XMLData.name to reference our variable
      allow(XMLData).to receive(:name) { character_name }

      # Mock startup to track when it's called
      allow(described_class).to receive(:startup) do
        startup_called = true
      end

      # Start the watch thread
      described_class.watch!
      thread = described_class.instance_variable_get(:@startup_thread)

      # Give thread a moment to start and check conditions (should be false)
      sleep 0.15

      # Startup should not have been called yet (conditions not met)
      expect(startup_called).to be false

      # Now simulate conditions being met by changing our variables
      autostarted = true
      character_name = 'TestCharacter'

      # Poll for startup to be called, with timeout
      # The thread checks every 0.1 seconds, so give it up to 2 seconds
      timeout = Time.now + 2
      until startup_called || Time.now > timeout
        sleep 0.05
      end

      # Now startup should have been called
      expect(startup_called).to be true
      expect(described_class).to have_received(:startup)

      # Clean up - kill thread if still running
      thread.kill if thread.alive?
    end
  end
end
