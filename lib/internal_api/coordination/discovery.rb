# frozen_string_literal: true

require_relative '../active_sessions'
require_relative '../coordination'

module Lich
  module InternalAPI
    module Coordination
      # Explicit bridge to the native process registry. Publication merges only
      # this metadata key into this process's existing character registration.
      # Native lifecycle heartbeats do not republish it after discovery loss.
      #
      # There is deliberately no unregister/close hook: the native API cannot
      # conditionally clear an old incarnation without racing its replacement.
      # A closed endpoint's retained descriptor is only a hint; resolution must
      # authenticate and check its complete identity before returning a client.
      class Discovery
        # @param enabled [Boolean] explicit opt-in for publication and resolution
        # @param active_sessions [#register_session, #query_snapshot] native registry API
        # @return [void]
        def initialize(enabled: false, active_sessions: ActiveSessions)
          @enabled = enabled == true
          @active_sessions = active_sessions
        end

        # @param session [Session] local started session whose descriptor is published
        # @return [Boolean] whether the native registry accepted the metadata
        def publish(session)
          return false unless @enabled

          descriptor = session.descriptor
          return false unless Schema.descriptor?(descriptor)

          @active_sessions.register_session(pid: Process.pid, coordination: descriptor) == true
        rescue StandardError
          false
        end

        # Credentials are supplied separately and never enter public metadata.
        # A caller pins the complete expected identity; PID/port/name matching
        # alone is insufficient. Each call queries current native discovery.
        # timeout bounds the endpoint handshake; the native registry query
        # retains ActiveSessions' existing transport behavior and timeout policy.
        # @param identity [Hash] complete expected peer identity, including incarnation and generation
        # @param read_token [String] separately supplied peer read credential
        # @param max_age [Numeric] maximum accepted snapshot and source age in seconds
        # @param timeout [Numeric] coordination endpoint request deadline in seconds
        # @return [Client, nil] authenticated identity-checked client, or nil when unavailable
        def resolve(identity:, read_token:, max_age: 1.0, timeout: 0.25)
          return nil unless @enabled && Schema.identity?(identity)

          snapshot = @active_sessions.query_snapshot
          return nil unless snapshot.is_a?(Hash) && !snapshot[:error] &&
                            snapshot[:source] == 'ActiveSessionsAPI' && snapshot[:sessions].is_a?(Array)

          matches = snapshot[:sessions].filter_map do |record|
            next unless record.is_a?(Hash) && record[:pid].is_a?(Integer) && record[:pid].positive?

            descriptor = record[:coordination]
            descriptor if Schema.descriptor?(descriptor) && descriptor[:identity] == identity
          end
          return nil unless matches.length == 1

          client = Client.new(descriptor: matches.first, read_token: read_token, max_age: max_age, timeout: timeout)
          client.ping ? client : nil
        rescue StandardError
          nil
        end
      end
    end
  end
end
