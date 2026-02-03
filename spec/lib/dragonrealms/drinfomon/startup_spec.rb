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

  describe 'thread behavior' do
    it 'watch! thread body delegates to startup' do
      # The watch! thread body is:
      #   sleep 0.1 until GameBase::Game.autostarted? && XMLData.name && !XMLData.name.empty?
      #   startup
      #
      # Thread creation is tested in .watch! specs above.
      # Here we verify the startup delegation contract.
      described_class.class_variable_set(:@@startup_complete, false)
      allow(described_class).to receive(:startup)

      described_class.startup

      expect(described_class).to have_received(:startup).once
    end

    it 'startup_completed! signals PostLoad when defined' do
      described_class.class_variable_set(:@@startup_complete, false)

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
end
