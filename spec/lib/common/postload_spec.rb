# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../lib/common/postload'

RSpec.describe Lich::Common::PostLoad do
  before do
    # Kill any lingering real thread from a previous example
    thread = described_class.instance_variable_get(:@thread)
    thread.kill if thread.is_a?(Thread) && thread.alive?
    described_class.instance_variable_set(:@thread, nil)
    described_class.instance_variable_set(:@callbacks, {})
    described_class.class_variable_set(:@@complete, false)
    described_class.class_variable_set(:@@game_loaded, false)
  end

  after do
    thread = described_class.instance_variable_get(:@thread)
    thread.kill if thread.is_a?(Thread) && thread.alive?
  end

  describe '.register' do
    it 'accepts a named callback with a block' do
      described_class.register("test") { "hello" }
      callbacks = described_class.instance_variable_get(:@callbacks)
      expect(callbacks).to have_key("test")
      expect(callbacks["test"]).to be_a(Proc)
    end

    it 'raises ArgumentError without a block' do
      expect { described_class.register("test") }.to raise_error(ArgumentError)
    end

    it 'replaces duplicate registrations by name' do
      described_class.register("test") { "first" }
      described_class.register("test") { "second" }
      callbacks = described_class.instance_variable_get(:@callbacks)
      expect(callbacks.size).to eq(1)
      expect(callbacks["test"].call).to eq("second")
    end

    it 'converts name to string' do
      described_class.register(:symbolic) { "yes" }
      callbacks = described_class.instance_variable_get(:@callbacks)
      expect(callbacks).to have_key("symbolic")
    end
  end

  describe '.game_loaded!' do
    it 'sets game_loaded? to true' do
      expect(described_class.game_loaded?).to be false
      described_class.game_loaded!
      expect(described_class.game_loaded?).to be true
    end
  end

  describe '.complete?' do
    it 'returns false initially' do
      expect(described_class.complete?).to be false
    end
  end

  describe '.watch!' do
    let(:mock_thread) { instance_double(Thread) }

    before do
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

    it 'stores the thread in @thread' do
      described_class.watch!
      expect(described_class.instance_variable_get(:@thread)).to eq(mock_thread)
    end
  end

  describe 'callback execution', :integration do
    it 'runs registered callbacks after game_loaded! signal' do
      skip "Threading test is flaky in CI - verified manually" if ENV['CI']

      callback_ran = false
      autostarted = true
      character_name = 'TestChar'

      allow(GameBase::Game).to receive(:autostarted?) { autostarted }
      allow(XMLData).to receive(:name) { character_name }

      described_class.register("test_cb") { callback_ran = true }
      described_class.watch!

      # Callbacks should not run yet (game_loaded not signaled)
      sleep 0.15
      expect(callback_ran).to be false

      # Signal game loaded
      described_class.game_loaded!

      # Wait for thread to process
      timeout = Time.now + 2
      sleep 0.05 until described_class.complete? || Time.now > timeout

      expect(callback_ran).to be true
      expect(described_class.complete?).to be true

      thread = described_class.instance_variable_get(:@thread)
      thread.kill if thread&.alive?
    end

    it 'does not run callbacks until base readiness is met' do
      skip "Threading test is flaky in CI - verified manually" if ENV['CI']

      callback_ran = false
      autostarted = false
      character_name = nil

      allow(GameBase::Game).to receive(:autostarted?) { autostarted }
      allow(XMLData).to receive(:name) { character_name }

      described_class.register("test_cb") { callback_ran = true }
      described_class.game_loaded!
      described_class.watch!

      # Even with game_loaded, base readiness not met
      sleep 0.25
      expect(callback_ran).to be false

      # Now meet base readiness
      autostarted = true
      character_name = 'TestChar'

      timeout = Time.now + 2
      sleep 0.05 until described_class.complete? || Time.now > timeout

      expect(callback_ran).to be true

      thread = described_class.instance_variable_get(:@thread)
      thread.kill if thread&.alive?
    end

    it 'isolates callback failures' do
      skip "Threading test is flaky in CI - verified manually" if ENV['CI']

      second_ran = false

      allow(GameBase::Game).to receive(:autostarted?).and_return(true)
      allow(XMLData).to receive(:name).and_return('TestChar')

      described_class.register("bad") { raise "boom" }
      described_class.register("good") { second_ran = true }

      described_class.game_loaded!
      described_class.watch!

      timeout = Time.now + 2
      sleep 0.05 until described_class.complete? || Time.now > timeout

      expect(second_ran).to be true
      expect(described_class.complete?).to be true

      thread = described_class.instance_variable_get(:@thread)
      thread.kill if thread&.alive?
    end
  end
end
