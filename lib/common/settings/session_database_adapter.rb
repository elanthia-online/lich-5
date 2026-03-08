# frozen_string_literal: true

require 'sqlite3'

module Lich
  module Common
    # Row-oriented adapter for session summary state.
    # This intentionally differs from blob-backed script_auto_settings storage.
    class SessionDatabaseAdapter
      DEFAULT_TABLE_NAME = 'session_summary_state'

      def initialize(db: nil, data_dir: DATA_DIR, table_name: DEFAULT_TABLE_NAME)
        @db = db || SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
        @table_name = table_name
      end

      def upsert_session(payload)
        with_retry do
          @db.execute(<<~SQL, bind_params(payload))
            INSERT INTO #{@table_name} (
              pid, ppid, session_name, role, state, frontend, game_code, hidden,
              started_at, last_heartbeat_at, last_utilization_at, metadata_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(pid) DO UPDATE SET
              ppid = COALESCE(excluded.ppid, #{@table_name}.ppid),
              session_name = COALESCE(excluded.session_name, #{@table_name}.session_name),
              role = COALESCE(excluded.role, #{@table_name}.role),
              state = COALESCE(excluded.state, #{@table_name}.state),
              frontend = COALESCE(excluded.frontend, #{@table_name}.frontend),
              game_code = COALESCE(excluded.game_code, #{@table_name}.game_code),
              hidden = COALESCE(excluded.hidden, #{@table_name}.hidden),
              started_at = COALESCE(excluded.started_at, #{@table_name}.started_at),
              last_heartbeat_at = COALESCE(excluded.last_heartbeat_at, #{@table_name}.last_heartbeat_at),
              last_utilization_at = COALESCE(excluded.last_utilization_at, #{@table_name}.last_utilization_at),
              metadata_json = COALESCE(excluded.metadata_json, #{@table_name}.metadata_json);
          SQL
        end
      end

      def active_sessions
        with_retry do
          rows_as_hashes("SELECT * FROM #{@table_name} ORDER BY pid ASC;")
        end
      end

      def delete_session(pid:)
        with_retry do
          @db.execute("DELETE FROM #{@table_name} WHERE pid = ?;", [pid])
        end
      end

      def duplicate_active_session_names
        with_retry do
          rows_as_hashes(<<~SQL)
            SELECT session_name, COUNT(*) AS duplicate_count
            FROM #{@table_name}
            WHERE session_name IS NOT NULL AND session_name != ''
            GROUP BY session_name
            HAVING COUNT(*) > 1
            ORDER BY session_name ASC;
          SQL
        end
      end

      private

      def bind_params(payload)
        [
          payload[:pid],
          payload[:ppid],
          payload[:session_name],
          payload[:role],
          payload[:state],
          payload[:frontend],
          payload[:game_code],
          payload.key?(:hidden) ? payload[:hidden] : nil,
          payload[:started_at],
          payload[:last_heartbeat_at],
          payload[:last_utilization_at],
          payload[:metadata_json]
        ]
      end

      def rows_as_hashes(sql)
        original_mode = @db.results_as_hash
        @db.results_as_hash = true
        raw_rows = @db.execute(sql)
        raw_rows.map do |row|
          # SQLite3::Database with results_as_hash=true returns both numeric and
          # string keys in each row hash. Filter to string keys for deterministic output.
          row.each_with_object({}) do |(key, value), cleaned|
            cleaned[key] = value if key.is_a?(String)
          end
        end
      ensure
        @db.results_as_hash = original_mode
      end

      def with_retry(max_attempts = 5)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue SQLite3::BusyException
          raise if attempts >= max_attempts

          sleep(0.05 * attempts)
          retry
        end
      end
    end
  end
end
