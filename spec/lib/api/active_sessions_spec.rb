# frozen_string_literal: true

require_relative '../../spec_helper'
require_relative '../../../lib/api/active_sessions'

RSpec.describe Lich::API do
  describe '.active_session_snapshot' do
    it 'returns an empty snapshot when the internal service is unavailable' do
      hide_const('Lich::InternalAPI')

      expect(described_class.active_session_snapshot).to eq(
        source: 'ActiveSessionsAPI',
        total: 0,
        connected: 0,
        detachable: 0,
        sessions: []
      )
    end

    it 'delegates to the internal active sessions service when available' do
      stub_const('Lich::InternalAPI', Module.new)
      active_sessions = Module.new
      stub_const('Lich::InternalAPI::ActiveSessions', active_sessions)
      allow(Lich::InternalAPI::ActiveSessions).to receive(:snapshot).and_return(
        source: 'ActiveSessionsAPI',
        total: 1,
        connected: 1,
        detachable: 0,
        sessions: [{ pid: 101 }]
      )

      expect(described_class.active_session_snapshot[:total]).to eq(1)
      expect(described_class.active_sessions).to eq([{ pid: 101 }])
    end
  end
end
