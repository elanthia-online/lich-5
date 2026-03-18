# frozen_string_literal: true

module Lich
  # Small public facade for the active sessions runtime service.
  #
  # This facade intentionally exposes only read operations. Internal lifecycle
  # registration, transport startup, and server ownership stay inside
  # `Lich::InternalAPI::ActiveSessions`.
  module API
    # Returns the normalized active sessions snapshot.
    #
    # @return [Hash] a normalized runtime snapshot or inert fallback payload
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
    # @return [Array<Hash>] the sessions array from {active_session_snapshot}
    def self.active_sessions
      active_session_snapshot[:sessions] || []
    end
  end
end
