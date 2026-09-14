# frozen_string_literal: true

require 'time'

module Lich
  module InternalAPI
    module ActiveSessions
      # In-memory authoritative store of active Lich sessions.
      #
      # The registry intentionally models only live runtime state. It is not a
      # historical store and removes sessions when they can no longer be
      # confirmed as resident in the OS process table.
      class Registry
        # @param time_source [#call] returns the current epoch seconds
        # @param process_checker [#call] returns true when a pid is still alive
        # @return [void]
        def initialize(time_source: -> { Time.now.to_i }, process_checker: self.class.method(:process_alive?))
          @time_source = time_source
          @process_checker = process_checker
          @sessions = {}
          @mutex = Mutex.new
        end

        # Adds or updates a live session record.
        #
        # @param payload [Hash] session metadata keyed by symbols or strings
        # @return [Hash] normalized stored session record
        def upsert(payload)
          data = symbolize_keys(payload)
          pid = Integer(data.fetch(:pid))
          now = @time_source.call

          @mutex.synchronize do
            current = @sessions[pid] || {}
            started_at = data[:started_at] || current[:started_at] || now
            merged = current.merge(mergeable_data(data))
            merged[:pid] = pid
            merged[:started_at] = started_at
            merged[:last_seen_at] = now
            merged[:connected] = !!merged[:connected]
            merged[:hidden] = !!merged[:hidden]
            @sessions[pid] = merged
          end

          session(pid)
        end

        # Removes a session record by pid.
        #
        # @param pid [Integer]
        # @return [Boolean] true when a record was removed
        def remove(pid)
          @mutex.synchronize { !@sessions.delete(pid.to_i).nil? }
        end

        # Returns a single session by pid.
        #
        # @param pid [Integer]
        # @return [Hash, nil]
        def session(pid)
          @mutex.synchronize do
            record = @sessions[pid.to_i]
            record ? record.dup : nil
          end
        end

        # Returns a read-only snapshot of current active sessions.
        #
        # @return [Hash] normalized snapshot payload for API consumers
        def snapshot
          sweep_dead_sessions!
          now = @time_source.call
          sessions = @mutex.synchronize { @sessions.values.map(&:dup) }
          normalized = sessions.sort_by { |session| session[:pid] }.map do |session|
            session.merge(
              uptime_seconds: [0, now - session[:started_at].to_i].max,
              listener: listener_hash(session)
            )
          end

          {
            source: 'ActiveSessionsAPI',
            total: normalized.length,
            connected: normalized.count { |session| session[:connected] },
            detachable: normalized.count { |session| session[:listener] },
            sessions: normalized
          }
        end

        # Removes sessions whose pids are no longer present in the OS process table.
        #
        # @return [void]
        def sweep_dead_sessions!
          dead_pids = @mutex.synchronize { @sessions.keys }.reject { |pid| @process_checker.call(pid) }
          return if dead_pids.empty?

          @mutex.synchronize do
            dead_pids.each { |pid| @sessions.delete(pid) }
          end
        end

        # Returns a non-persistent empty snapshot for failure or unavailable states.
        #
        # @param error [String, nil]
        # @return [Hash]
        def empty_snapshot(error: nil)
          {
            source: 'ActiveSessionsAPI',
            total: 0,
            connected: 0,
            detachable: 0,
            sessions: [],
            error: error
          }.compact
        end

        # Checks whether a pid is resident in the local OS process table.
        #
        # @param pid [Integer]
        # @return [Boolean]
        def self.process_alive?(pid)
          Process.kill(0, pid.to_i)
          true
        rescue Errno::ESRCH
          false
        rescue Errno::EPERM
          true
        rescue StandardError
          false
        end

        private

        # Normalizes incoming hash keys to symbols so the registry can accept
        # either JSON-decoded strings or symbol-keyed Ruby hashes.
        #
        # @param hash [Hash]
        # @return [Hash]
        def symbolize_keys(hash)
          hash.each_with_object({}) do |(key, value), normalized|
            normalized[key.to_sym] = value
          end
        end

        # Filters incoming session data before merging it with any existing
        # session record.
        #
        # Listener host and port are intentionally allowed to overwrite with
        # `nil` so detachable listener cleanup can clear those fields.
        #
        # @param data [Hash]
        # @return [Hash]
        def mergeable_data(data)
          data.each_with_object({}) do |(key, value), merged|
            next if value.nil? && !%i[listener_host listener_port].include?(key)

            merged[key] = value
          end
        end
        private :mergeable_data

        # Returns the detached-listener sub-hash for a session when the session
        # is currently advertising a local listener.
        #
        # @param session [Hash]
        # @return [Hash, nil]
        def listener_hash(session)
          return nil if session[:listener_port].nil?

          {
            host: session[:listener_host] || '127.0.0.1',
            port: session[:listener_port].to_i
          }
        end
      end
    end
  end
end
