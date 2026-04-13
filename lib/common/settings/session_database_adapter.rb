# frozen_string_literal: true

require 'sqlite3'

module Lich
  module Common
    # Row-oriented adapter for session summary state.
    # This intentionally differs from blob-backed script_auto_settings storage.
    class SessionDatabaseAdapter
      DEFAULT_TABLE_NAME = 'session_summary_state'

      # Builds an adapter bound to a row-oriented session summary table.
      #
      # @param db [SQLite3::Database, nil] optional injected database connection
      # @param data_dir [String] directory containing lich.db3 when db is not injected
      # @param table_name [String] session summary table name
      def initialize(db: nil, data_dir: DATA_DIR, table_name: DEFAULT_TABLE_NAME)
        @db = db || begin
          conn = SQLite3::Database.new(File.join(data_dir, 'lich.db3'))
          conn.busy_timeout = 3000
          conn
        end
        @table_name = table_name
      end

      # Inserts or updates a session row by pid.
      #
      # @param payload [Hash] row fields for insert/update
      # @return [void]
      def upsert_session(payload)
        with_retry do
          @db.execute(<<~SQL, bind_params(payload))
            INSERT INTO #{@table_name} (
              pid, session_name, role, state, frontend, game_code, hidden,
              started_at, last_heartbeat_at, os_seen_at, os_seen, os_name, last_utilization_at, metadata_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(pid) DO UPDATE SET
              session_name = COALESCE(excluded.session_name, #{@table_name}.session_name),
              role = COALESCE(excluded.role, #{@table_name}.role),
              state = COALESCE(excluded.state, #{@table_name}.state),
              frontend = COALESCE(excluded.frontend, #{@table_name}.frontend),
              game_code = COALESCE(excluded.game_code, #{@table_name}.game_code),
              hidden = COALESCE(excluded.hidden, #{@table_name}.hidden),
              started_at = COALESCE(excluded.started_at, #{@table_name}.started_at),
              last_heartbeat_at = COALESCE(excluded.last_heartbeat_at, #{@table_name}.last_heartbeat_at),
              os_seen_at = COALESCE(excluded.os_seen_at, #{@table_name}.os_seen_at),
              os_seen = COALESCE(excluded.os_seen, #{@table_name}.os_seen),
              os_name = COALESCE(excluded.os_name, #{@table_name}.os_name),
              last_utilization_at = COALESCE(excluded.last_utilization_at, #{@table_name}.last_utilization_at),
              metadata_json = COALESCE(excluded.metadata_json, #{@table_name}.metadata_json);
          SQL
        end
      end

      # Returns all rows currently tracked in the session summary table.
      #
      # @return [Array<Hash>] rows sorted by pid
      def active_sessions
        with_retry do
          rows_as_hashes("SELECT * FROM #{@table_name} ORDER BY pid ASC;")
        end
      end

      # Deletes a row for the provided pid.
      #
      # @param pid [Integer]
      # @return [void]
      def delete_session(pid:)
        with_retry do
          @db.execute("DELETE FROM #{@table_name} WHERE pid = ?;", [pid])
        end
      end

      # Finds one row by pid.
      #
      # @param pid [Integer]
      # @return [Hash, nil]
      def find_session(pid:)
        with_retry do
          rows_as_hashes("SELECT * FROM #{@table_name} WHERE pid = ? LIMIT 1;", [pid.to_i]).first
        end
      end

      # Returns names that currently appear more than once.
      # Duplicate names are treated as data points, not enforcement failures.
      #
      # @return [Array<Hash>] rows containing `session_name` and `duplicate_count`
      def duplicate_active_session_names
        with_retry do
          rows_as_hashes(<<~SQL)
            SELECT session_name, COUNT(*) AS duplicate_count
            FROM #{@table_name}
            WHERE session_name IS NOT NULL
              AND session_name != ''
              AND COALESCE(state, '') != 'exited'
            GROUP BY session_name
            HAVING COUNT(*) > 1
            ORDER BY session_name ASC;
          SQL
        end
      end

      # Returns rows that still appear active in storage and may need a
      # liveness sweep against the current OS process table.
      #
      # @return [Array<Hash>] non-exited rows sorted by pid
      def tracked_live_candidates
        with_retry do
          rows_as_hashes(<<~SQL)
            SELECT * FROM #{@table_name}
            WHERE COALESCE(state, '') != 'exited'
            ORDER BY pid ASC;
          SQL
        end
      end

      private

      # Binds payload values in stable column order for upsert SQL.
      #
      # @param payload [Hash]
      # @return [Array]
      def bind_params(payload)
        [
          payload[:pid],
          payload[:session_name],
          payload[:role],
          payload[:state],
          payload[:frontend],
          payload[:game_code],
          payload.key?(:hidden) ? payload[:hidden] : nil,
          payload[:started_at],
          payload[:last_heartbeat_at],
          payload[:os_seen_at],
          payload.key?(:os_seen) ? payload[:os_seen] : nil,
          payload.key?(:os_name) ? payload[:os_name] : nil,
          payload[:last_utilization_at],
          payload[:metadata_json]
        ]
      end

      # Executes a query and normalizes sqlite hash rows to string-keyed hashes.
      #
      # @param sql [String]
      # @param binds [Array] optional bind values used for placeholders in +sql+
      # @return [Array<Hash>]
      def rows_as_hashes(sql, binds = [])
        rows_with_headers = @db.execute2(sql, binds)
        headers = rows_with_headers.shift || []
        rows_with_headers.map do |row|
          if row.is_a?(Array)
            headers.each_with_index.with_object({}) do |(column, idx), cleaned|
              cleaned[column] = row[idx]
            end
          else
            headers.each_with_object({}) do |column, cleaned|
              cleaned[column] = row[column]
            end
          end
        end
      end

      # Retries DB work for transient sqlite busy locks.
      #
      # @param max_attempts [Integer]
      # @yieldreturn [Object]
      # @return [Object]
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
