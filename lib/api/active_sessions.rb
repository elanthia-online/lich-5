# frozen_string_literal: true

module Lich
  # Small public facade for the active sessions runtime service.
  module API
    # Returns the normalized active sessions snapshot.
    #
    # @return [Hash]
    def self.active_session_snapshot
      return {
        source: 'ActiveSessionsAPI',
        total: 0,
        connected: 0,
        detachable: 0,
        sessions: []
      } unless defined?(Lich::InternalAPI::ActiveSessions)

      Lich::InternalAPI::ActiveSessions.snapshot
    end

    # Returns the currently known active sessions list.
    #
    # @return [Array<Hash>]
    def self.active_sessions
      active_session_snapshot[:sessions] || []
    end
  end
end
