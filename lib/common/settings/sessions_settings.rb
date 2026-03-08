# frozen_string_literal: true

require_relative 'session_database_adapter'

module Lich
  module Common
    # Lightweight session summary facade for reporting consumers.
    # This module is intentionally reporting-focused and does not enforce process policy.
    module SessionsSettings
      HEARTBEAT_INTERVAL_SECONDS = 90
      STALE_THRESHOLD_SECONDS = 360
      IDLE_OVER_30M_SECONDS = 1800

      def self.adapter
        @adapter ||= SessionDatabaseAdapter.new(db: Lich.db)
      end

      def self.register_session(pid:, session_name:, role:, state:, ppid: nil, frontend: nil, game_code: nil, hidden: false, metadata_json: nil)
        now = Time.now.to_i
        adapter.upsert_session(
          pid: pid,
          ppid: ppid,
          session_name: session_name,
          role: role,
          state: state,
          frontend: frontend,
          game_code: game_code,
          hidden: hidden ? 1 : 0,
          started_at: now,
          last_heartbeat_at: now,
          metadata_json: metadata_json
        )
      end

      def self.heartbeat(pid:, state: nil, hidden: nil, last_utilization_at: nil)
        adapter.upsert_session(
          pid: pid,
          state: state,
          hidden: hidden.nil? ? nil : (hidden ? 1 : 0),
          last_heartbeat_at: Time.now.to_i,
          last_utilization_at: last_utilization_at
        )
      end

      def self.unregister_session(pid:)
        adapter.delete_session(pid: pid)
      end

      def self.snapshot
        rows = adapter.active_sessions
        now = Time.now.to_i
        sessions = rows.map do |row|
          {
            pid: row['pid'],
            session_name: row['session_name'],
            state: row['state'],
            hidden: row['hidden'].to_i == 1,
            role: row['role'],
            last_heartbeat_at: row['last_heartbeat_at'].to_i,
            heartbeat_age: heartbeat_age(row['last_heartbeat_at'], now),
            stale: stale?(row['last_heartbeat_at'], now),
            marker: stale?(row['last_heartbeat_at'], now) ? 'stale' : 'active',
            last_utilization: format_last_utilization(row['last_utilization_at'], now)
          }
        end

        {
          source: 'SessionSettings',
          total: sessions.length,
          idle_over_30m: sessions.count { |s| !s[:heartbeat_age].nil? && s[:heartbeat_age] > IDLE_OVER_30M_SECONDS },
          stale: sessions.count { |s| s[:stale] },
          running: sessions.count { |s| s[:state] == 'running' },
          sleeping: sessions.count { |s| s[:state] == 'sleeping' },
          hidden: sessions.count { |s| s[:hidden] },
          sessions: sessions
        }
      rescue StandardError => e
        {
          source: 'SessionSettings',
          total: 0,
          idle_over_30m: 0,
          running: 0,
          sleeping: 0,
          hidden: 0,
          sessions: [],
          error: e.message
        }
      end

      def self.format_last_utilization(last_utilization_at, now_epoch)
        return nil if last_utilization_at.nil?

        seconds_ago = now_epoch - last_utilization_at.to_i
        seconds_ago.negative? ? 0 : seconds_ago
      end
      private_class_method :format_last_utilization

      def self.heartbeat_age(last_heartbeat_at, now_epoch)
        return nil if last_heartbeat_at.nil?

        age = now_epoch - last_heartbeat_at.to_i
        age.negative? ? 0 : age
      end
      private_class_method :heartbeat_age

      def self.stale?(last_heartbeat_at, now_epoch)
        age = heartbeat_age(last_heartbeat_at, now_epoch)
        !age.nil? && age > STALE_THRESHOLD_SECONDS
      end
      private_class_method :stale?
    end
  end
end
