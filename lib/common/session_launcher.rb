# frozen_string_literal: true

require 'rbconfig'

module Lich
  module Common
    # Launches independent child Lich sessions using prepared launch_data.
    # Returns structured status hashes so GUI callers can display outcomes.
    module SessionLauncher
      # Grace period before parent attempts to delete SAL file.
      SAL_DELETE_GRACE_SECONDS = 5
      # Maximum parent-side retry window for SAL deletion.
      SAL_DELETE_RETRY_SECONDS = 5
      # Delay between SAL deletion retries.
      SAL_DELETE_RETRY_INTERVAL = 0.25

      class << self
        # Launches a child Lich process from prebuilt launch data.
        #
        # @param launch_data [Array<String>] Launch lines compatible with SAL format
        # @return [Hash] Structured result:
        #   - success: { ok: true, pid: Integer, sal_path: String }
        #   - failure: { ok: false, error: String }
        def launch(launch_data)
          unless launch_data.is_a?(Array) && launch_data.any?
            return { ok: false, error: 'launch_data must be a non-empty Array' }
          end

          sal_path = write_sal_file(launch_data)
          pid = spawn_process(sal_path)
          cleanup_sal_file_async(sal_path, grace_seconds: SAL_DELETE_GRACE_SECONDS)
          { ok: true, pid: pid, sal_path: sal_path }
        rescue StandardError => e
          cleanup_sal_file_async(sal_path, grace_seconds: 0) if sal_path
          { ok: false, error: e.message }
        end

        private

        # Writes launch data to a SAL file in temp storage.
        #
        # @param launch_data [Array<String>]
        # @return [String] Absolute SAL path
        def write_sal_file(launch_data)
          temp_dir = defined?(TEMP_DIR) ? TEMP_DIR : '/tmp'
          sal_path = File.join(temp_dir, "lich-session-#{Time.now.to_i}-#{rand(10000)}.sal")
          File.open(sal_path, 'w') { |f| f.puts launch_data }
          sal_path
        end

        # Spawns a new Lich process using positional SAL arg parsing semantics.
        #
        # @param sal_path [String]
        # @return [Integer] Child PID
        def spawn_process(sal_path)
          ruby_bin = RbConfig.ruby
          entrypoint = File.expand_path($PROGRAM_NAME)
          working_dir = defined?(LICH_DIR) ? LICH_DIR : Dir.pwd

          # Argv parser detects launch files by "*.sal" positional argument.
          spawn(ruby_bin, entrypoint, sal_path, chdir: working_dir)
        end

        # Starts asynchronous SAL cleanup to avoid blocking launch callbacks.
        #
        # @param sal_path [String]
        # @param grace_seconds [Numeric]
        # @return [Thread]
        def cleanup_sal_file_async(sal_path, grace_seconds:)
          Thread.new do
            cleanup_sal_file_with_retry(sal_path, grace_seconds: grace_seconds)
          end
        end

        # Parent-side SAL cleanup with grace+retry window to avoid deleting
        # before a child process has fully started reading the launch file.
        #
        # @param sal_path [String]
        # @param grace_seconds [Numeric]
        # @return [void]
        def cleanup_sal_file_with_retry(sal_path, grace_seconds:)
          return unless sal_path

          sleep(grace_seconds) if grace_seconds.positive?
          deadline = Time.now + SAL_DELETE_RETRY_SECONDS

          loop do
            begin
              File.delete(sal_path)
              return
            rescue Errno::ENOENT
              return
            rescue StandardError
              return if Time.now >= deadline
              sleep(SAL_DELETE_RETRY_INTERVAL)
            end
          end
        end
      end
    end
  end
end
