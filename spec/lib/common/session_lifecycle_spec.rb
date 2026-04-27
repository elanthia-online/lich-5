# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/session_lifecycle'

RSpec.describe Lich::Common::SessionLifecycle do
  # Resets module-level state between examples because lifecycle behavior is
  # implemented as module singleton state, not per-instance objects.
  before(:each) do
    stub_const('Lich::Common::SessionsSettings', Module.new)
    allow(Lich::Common::SessionsSettings).to receive(:enabled?).and_return(true)
    allow(Lich::Common::SessionsSettings).to receive(:register_session)
    allow(Lich::Common::SessionsSettings).to receive(:heartbeat)
    allow(Lich::Common::SessionsSettings).to receive(:unregister_session)
    allow(Lich::Common::SessionsSettings).to receive(:HEARTBEAT_INTERVAL_SECONDS).and_return(90)
    stub_const('Lich', Lich) unless defined?(Lich)
    allow(Lich).to receive(:log) if Lich.respond_to?(:log)

    described_class.instance_variable_set(:@running, false)
    described_class.instance_variable_set(:@started, false)
    described_class.instance_variable_set(:@heartbeat_thread, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
  end

  describe '.resolve_session_name' do
    # Validates deterministic fallback order for session naming.
    it 'uses --login character when present' do
      result = described_class.resolve_session_name(argv: ['--login', 'tsetem'], account_character: nil)
      expect(result).to eq('Tsetem')
    end

    it 'falls back to account_character when login arg is absent' do
      result = described_class.resolve_session_name(argv: [], account_character: 'Abyran')
      expect(result).to eq('Abyran')
    end

    it 'falls back to XMLData.name when argv and account character are absent' do
      stub_const('XMLData', double('XMLData', name: 'FromXmlData'))

      result = described_class.resolve_session_name(argv: [], account_character: nil)
      expect(result).to eq('FromXmlData')
    end

    it 'falls back to pid format when XMLData.name is unavailable' do
      stub_const('XMLData', double('XMLData', name: nil))
      allow(Process).to receive(:pid).and_return(1234)

      result = described_class.resolve_session_name(argv: [], account_character: nil)
      expect(result).to eq('pid-1234')
    end

    it 'falls back to pid format when XMLData.name is empty' do
      stub_const('XMLData', double('XMLData', name: ''))
      allow(Process).to receive(:pid).and_return(5678)

      result = described_class.resolve_session_name(argv: [], account_character: nil)
      expect(result).to eq('pid-5678')
    end
  end

  describe '.resolve_role' do
    # Ensures role classification reflects launch mode and detachable behavior.
    it 'returns headless for --without-frontend' do
      expect(described_class.resolve_role(argv: ['--without-frontend'], detachable_client_port: nil)).to eq('headless')
    end

    it 'returns detachable when detachable client is enabled' do
      expect(described_class.resolve_role(argv: [], detachable_client_port: 7000)).to eq('detachable')
    end

    it 'prefers detachable when headless mode also exposes a detachable client' do
      expect(described_class.resolve_role(argv: ['--without-frontend'], detachable_client_port: 7000)).to eq('detachable')
    end

    it 'returns session otherwise' do
      expect(described_class.resolve_role(argv: [], detachable_client_port: nil)).to eq('session')
    end
  end

  describe 'registration delay' do
    it 'defaults to 5 seconds for faster startup registration' do
      expect(described_class::REGISTRATION_DELAY_SECONDS).to eq(5)
    end
  end

  describe '.start / .stop' do
    # Verifies idempotent lifecycle transitions and clean unregister semantics.
    it 'does not start or stop lifecycle tracking while the feature flag is disabled' do
      allow(Lich::Common::SessionsSettings).to receive(:enabled?).and_return(false)

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be(false)
      expect(described_class.stop).to be(false)
      expect(Lich::Common::SessionsSettings).not_to have_received(:register_session)
      expect(Lich::Common::SessionsSettings).not_to have_received(:heartbeat)
      expect(Lich::Common::SessionsSettings).not_to have_received(:unregister_session)
    end

    it 'starts once and unregisters on stop (registration is deferred)' do
      fake_thread = instance_double(Thread, kill: true)
      allow(Thread).to receive(:new).and_return(fake_thread)
      allow(fake_thread).to receive(:join).with(0.5)
      allow(fake_thread).to receive(:alive?).and_return(true)
      allow(described_class).to receive(:resolve_frontend).and_return('stormfront')
      allow(described_class).to receive(:resolve_game_code).and_return('DR')

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be true
      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be false
      expect(Lich::Common::SessionsSettings).not_to have_received(:register_session)

      expect(described_class.stop).to be true
      expect(described_class.stop).to be false
      expect(Lich::Common::SessionsSettings).to have_received(:unregister_session).with(pid: Process.pid).once
    end

    it 'prefers cooperative heartbeat shutdown before hard kill' do
      heartbeat_thread = instance_double(Thread)
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      allow(Thread).to receive(:new).and_return(heartbeat_thread)
      allow(described_class).to receive(:resolve_frontend).and_return('stormfront')
      allow(described_class).to receive(:resolve_game_code).and_return('DR')

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be(true)
      expect(described_class.stop).to be(true)

      expect(heartbeat_thread).to have_received(:join).with(0.5)
      expect(heartbeat_thread).not_to have_received(:kill)
    end

    it 'uses hard kill when cooperative join times out' do
      heartbeat_thread = instance_double(Thread)
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(true)
      allow(heartbeat_thread).to receive(:kill)

      allow(Thread).to receive(:new).and_return(heartbeat_thread)
      allow(described_class).to receive(:resolve_frontend).and_return('stormfront')
      allow(described_class).to receive(:resolve_game_code).and_return('DR')

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be(true)
      expect(described_class.stop).to be(true)

      expect(heartbeat_thread).to have_received(:join).with(0.5)
      expect(heartbeat_thread).to have_received(:kill)
    end

    it 'executes deferred register and one heartbeat iteration from captured thread block' do
      heartbeat_thread = instance_double(Thread)
      allow(heartbeat_thread).to receive(:join).with(0.5)
      allow(heartbeat_thread).to receive(:alive?).and_return(false)
      allow(heartbeat_thread).to receive(:kill)

      captured_block = nil
      allow(Thread).to receive(:new) do |&blk|
        captured_block = blk
        heartbeat_thread
      end

      allow(described_class).to receive(:resolve_frontend).and_return('stormfront')
      allow(described_class).to receive(:resolve_game_code).and_return('DR')
      allow(described_class).to receive(:attempt_register).and_return(true)

      sleep_calls = 0
      allow(described_class).to receive(:sleep) do |_seconds|
        sleep_calls += 1
        described_class.instance_variable_set(:@running, false) if sleep_calls >= 3
      end

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 1, registration_delay: 0)).to be(true)
      expect(captured_block).not_to be_nil

      captured_block.call

      expect(described_class).to have_received(:attempt_register).at_least(:once)
      expect(Lich::Common::SessionsSettings).to have_received(:heartbeat).with(
        hash_including(
          pid: Process.pid,
          state: 'running',
          session_name: 'Tsetem',
          role: 'session',
          frontend: 'stormfront',
          game_code: 'DR'
        )
      ).at_least(:once)

      expect(described_class.stop).to be(true)
    end

    it 'resets lifecycle state when thread creation raises' do
      allow(described_class).to receive(:resolve_frontend).and_return('stormfront')
      allow(Thread).to receive(:new).and_raise(StandardError, 'thread create failed')

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be(false)
      expect(described_class.instance_variable_get(:@running)).to be(false)
      expect(described_class.instance_variable_get(:@started)).to be(false)
      expect(described_class.instance_variable_get(:@heartbeat_thread)).to be_nil
    end
  end

  describe '.resolve_game_code' do
    it 'returns nil when XMLData.game is an empty string' do
      stub_const('XMLData', double('XMLData', game: ''))

      expect(described_class.resolve_game_code).to be_nil
    end
  end
end
