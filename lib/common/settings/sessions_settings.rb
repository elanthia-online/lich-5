# frozen_string_literal: true

require_relative 'session_database_adapter'
require 'rbconfig'

module Lich
  module Common
    # Lightweight session summary facade for reporting consumers.
    # This module is intentionally reporting-focused and does not enforce process policy.
    module SessionsSettings
      FEATURE_FLAG = :session_summary_store_and_reporting
      HEARTBEAT_INTERVAL_SECONDS = 90
      STALE_THRESHOLD_SECONDS = 360
      IDLE_OVER_30M_SECONDS = 1800
      ADAPTER_MUTEX = Mutex.new

      # Indicates whether session summary tracking/reporting is enabled.
      #
      # The feature flag infrastructure is introduced in a separate prerequisite
      # change. Until that dependency is present, this feature remains safely off.
      #
      # @return [Boolean]
      def self.enabled?
        return false unless defined?(Lich::Common::FeatureFlags)

        Lich::Common::FeatureFlags.enabled?(FEATURE_FLAG)
      end

      # Returns the row-oriented session adapter.
      # Uses synchronized lazy initialization to avoid duplicate adapter creation
      # under concurrent access during startup/reporting.
      #
      # @return [Lich::Common::SessionDatabaseAdapter]
      def self.adapter
        return @adapter if @adapter

        ADAPTER_MUTEX.synchronize do
          @adapter ||= SessionDatabaseAdapter.new(db: Lich.db)
        end
      end

      # Registers a process as a tracked session row.
      #
      # @param pid [Integer]
      # @param session_name [String]
      # @param role [String]
      # @param state [String]
      # @param frontend [String, nil]
      # @param game_code [String, nil]
      # @param hidden [Boolean]
      # @param metadata_json [String, nil]
      # @return [void]
      def self.register_session(pid:, session_name:, role:, state:, frontend: nil, game_code: nil, hidden: false, metadata_json: nil)
        return unless enabled?

        now = Time.now.to_i
        os_presence_state = os_presence(pid: pid, session_name: session_name, now: now)
        adapter.upsert_session(
          pid: pid,
          session_name: session_name,
          role: role,
          state: state,
          frontend: frontend,
          game_code: game_code,
          hidden: hidden ? 1 : 0,
          started_at: now,
          last_heartbeat_at: now,
          os_seen_at: os_presence_state[:os_seen_at],
          os_seen: os_presence_state[:os_seen],
          os_name: os_presence_state[:os_name],
          metadata_json: metadata_json
        )
      end

      # Updates heartbeat and runtime fields for a tracked session.
      #
      # @param pid [Integer]
      # @param state [String, nil]
      # @param hidden [Boolean, nil]
      # @param session_name [String, nil]
      # @param role [String, nil]
      # @param frontend [String, nil]
      # @param game_code [String, nil]
      # @param last_utilization_at [Integer, nil]
      # @return [void]
      def self.heartbeat(pid:, state: nil, hidden: nil, session_name: nil, role: nil, frontend: nil, game_code: nil, last_utilization_at: nil)
        return unless enabled?

        now = Time.now.to_i
        session_name = session_name || adapter.find_session(pid: pid)&.fetch('session_name', nil)
        os_presence_state = os_presence(pid: pid, session_name: session_name, now: now)
        adapter.upsert_session(
          pid: pid,
          session_name: session_name,
          role: role,
          state: state,
          frontend: frontend,
          game_code: game_code,
          hidden: hidden.nil? ? nil : (hidden ? 1 : 0),
          last_heartbeat_at: now,
          os_seen_at: os_presence_state[:os_seen_at],
          os_seen: os_presence_state[:os_seen],
          os_name: os_presence_state[:os_name],
          last_utilization_at: last_utilization_at
        )
      end

      # Marks a tracked session as cleanly exited.
      #
      # @param pid [Integer]
      # @return [void]
      def self.unregister_session(pid:)
        return unless enabled?

        now = Time.now.to_i
        adapter.upsert_session(
          pid: pid,
          state: 'exited',
          os_seen_at: now,
          os_seen: 0,
          os_name: 0
        )
      end

      # Builds a normalized reporting snapshot from tracked session rows.
      #
      # @return [Hash] deterministic schema consumed by reporting callers
      def self.snapshot
        return disabled_snapshot unless enabled?

        rows = adapter.active_sessions
        now = Time.now.to_i
        sessions = rows.map do |row|
          os_seen = row['os_seen']
          os_name = row['os_name']
          if os_seen.nil?
            # Reporting path fallback only; no persistence mutation.
            fallback_presence = os_presence(pid: row['pid'], session_name: row['session_name'], now: now)
            os_seen = fallback_presence[:os_seen]
            os_name = fallback_presence[:os_name]
          end
          heartbeat_is_stale = stale?(row['last_heartbeat_at'], now)
          inactive = row['state'] == 'exited'
          stale = !inactive && (heartbeat_is_stale || os_seen.to_i == 0)
          marker = inactive ? 'inactive' : (stale ? 'stale' : 'active')
          {
            pid: row['pid'],
            session_name: row['session_name'],
            state: row['state'],
            hidden: row['hidden'].to_i == 1,
            role: row['role'],
            last_heartbeat_at: row['last_heartbeat_at'].to_i,
            heartbeat_age: heartbeat_age(row['last_heartbeat_at'], now),
            stale: stale,
            marker: marker,
            os_seen: os_seen.to_i == 1,
            os_name: os_name.nil? ? nil : (os_name.to_i == 1),
            last_utilization: format_last_utilization(row['last_utilization_at'], now)
          }
        end

        {
          source: 'SessionsSettings',
          total: sessions.length,
          idle_over_30m: sessions.count { |s| !s[:heartbeat_age].nil? && s[:heartbeat_age] > IDLE_OVER_30M_SECONDS },
          stale: sessions.count { |s| s[:stale] },
          running: sessions.count { |s| s[:state] == 'running' },
          sleeping: sessions.count { |s| s[:state] == 'sleeping' },
          hidden: sessions.count { |s| s[:hidden] },
          sessions: sessions
        }
      rescue StandardError => e
        disabled_snapshot(error: e.message)
      end

      # Converts a utilization timestamp into age-in-seconds.
      #
      # @param last_utilization_at [Integer, nil]
      # @param now_epoch [Integer]
      # @return [Integer, nil]
      def self.format_last_utilization(last_utilization_at, now_epoch)
        return nil if last_utilization_at.nil?

        seconds_ago = now_epoch - last_utilization_at.to_i
        seconds_ago.negative? ? 0 : seconds_ago
      end
      private_class_method :format_last_utilization

      # Computes heartbeat age in seconds.
      #
      # @param last_heartbeat_at [Integer, nil]
      # @param now_epoch [Integer]
      # @return [Integer, nil]
      def self.heartbeat_age(last_heartbeat_at, now_epoch)
        return nil if last_heartbeat_at.nil?

        age = now_epoch - last_heartbeat_at.to_i
        age.negative? ? 0 : age
      end
      private_class_method :heartbeat_age

      # Classifies whether a heartbeat timestamp is stale.
      #
      # @param last_heartbeat_at [Integer, nil]
      # @param now_epoch [Integer]
      # @return [Boolean]
      def self.stale?(last_heartbeat_at, now_epoch)
        age = heartbeat_age(last_heartbeat_at, now_epoch)
        !age.nil? && age > STALE_THRESHOLD_SECONDS
      end
      private_class_method :stale?

      # Performs non-mutating OS visibility checks used by reporting.
      #
      # @param pid [Integer]
      # @param session_name [String, nil]
      # @param now [Integer]
      # @return [Hash] os_seen_at, os_seen, and os_name fields
      def self.os_presence(pid:, session_name:, now: Time.now.to_i)
        seen = process_alive?(pid)
        name_match = if seen
                       name_matches_process?(pid, session_name)
                     else
                       0
                     end
        {
          os_seen_at: now,
          os_seen: seen ? 1 : 0,
          os_name: name_match
        }
      end

      # Checks whether pid is currently visible to the OS process table.
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
      private_class_method :process_alive?

      # Compares expected session name with process command line when available.
      #
      # @param pid [Integer]
      # @param session_name [String, nil]
      # @return [Integer, nil] 1 match, 0 mismatch, nil unavailable
      def self.name_matches_process?(pid, session_name)
        return nil if session_name.to_s.strip.empty?

        cmdline = process_command_line(pid)
        return nil if cmdline.nil? || cmdline.empty?

        cmdline.downcase.include?(session_name.to_s.downcase) ? 1 : 0
      rescue StandardError
        nil
      end
      private_class_method :name_matches_process?
      private_class_method :os_presence

      # Returns OS command line string for a process when supported by platform.
      #
      # @param pid [Integer]
      # @return [String, nil]
      def self.process_command_line(pid)
        case RbConfig::CONFIG['host_os']
        when /linux/, /darwin|mac os/
          `ps -o command= -p #{pid.to_i} 2>/dev/null`.to_s.strip
        when /mswin|mingw|cygwin/
          script = "(Get-CimInstance Win32_Process -Filter \"ProcessId = #{pid.to_i}\").CommandLine"
          output = `powershell.exe -WindowStyle Hidden -NoProfile -Command "#{script}" 2>NUL`.to_s.strip
          output.empty? ? nil : output
        else
          nil
        end
      rescue StandardError
        nil
      end
      private_class_method :process_command_line

      # Returns a deterministic empty payload used when the feature is disabled
      # or when reporting encounters an adapter/runtime error.
      #
      # @param error [String, nil] optional error detail for reporting callers
      # @return [Hash]
      def self.disabled_snapshot(error: nil)
        {
          source: 'SessionsSettings',
          total: 0,
          idle_over_30m: 0,
          stale: 0,
          running: 0,
          sleeping: 0,
          hidden: 0,
          sessions: [],
          error: error
        }.compact
      end
      private_class_method :disabled_snapshot
    end
  end
end
