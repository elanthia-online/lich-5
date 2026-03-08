# frozen_string_literal: true

require 'rspec'

require_relative '../../../lib/common/session_lifecycle'

RSpec.describe Lich::Common::SessionLifecycle do
  before(:each) do
    stub_const('Lich::Common::SessionsSettings', Module.new)
    allow(Lich::Common::SessionsSettings).to receive(:register_session)
    allow(Lich::Common::SessionsSettings).to receive(:heartbeat)
    allow(Lich::Common::SessionsSettings).to receive(:unregister_session)
    stub_const('Lich', Lich) unless defined?(Lich)
    allow(Lich).to receive(:log) if Lich.respond_to?(:log)

    described_class.instance_variable_set(:@running, false)
    described_class.instance_variable_set(:@started, false)
    described_class.instance_variable_set(:@heartbeat_thread, nil)
    described_class.instance_variable_set(:@mutex, Mutex.new)
  end

  describe '.resolve_session_name' do
    it 'uses --login character when present' do
      result = described_class.resolve_session_name(argv: ['--login', 'tsetem'], account_character: nil)
      expect(result).to eq('Tsetem')
    end

    it 'falls back to account_character when login arg is absent' do
      result = described_class.resolve_session_name(argv: [], account_character: 'Abyran')
      expect(result).to eq('Abyran')
    end
  end

  describe '.resolve_role' do
    it 'returns headless for --without-frontend' do
      expect(described_class.resolve_role(argv: ['--without-frontend'], detachable_client_port: nil)).to eq('headless')
    end

    it 'returns detachable when detachable client is enabled' do
      expect(described_class.resolve_role(argv: [], detachable_client_port: 7000)).to eq('detachable')
    end

    it 'returns session otherwise' do
      expect(described_class.resolve_role(argv: [], detachable_client_port: nil)).to eq('session')
    end
  end

  describe '.start / .stop' do
    it 'starts once and unregisters on stop (registration is deferred)' do
      fake_thread = instance_double(Thread, kill: true)
      allow(Thread).to receive(:new).and_return(fake_thread)

      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be true
      expect(described_class.start(session_name: 'Tsetem', role: 'session', heartbeat_interval: 999)).to be false
      expect(Lich::Common::SessionsSettings).not_to have_received(:register_session)

      expect(described_class.stop).to be true
      expect(described_class.stop).to be false
      expect(Lich::Common::SessionsSettings).to have_received(:unregister_session).with(pid: Process.pid).once
    end
  end
end
