# frozen_string_literal: true

require_relative 'error'
require_relative 'logger'
require_relative 'config'
require_relative 'file_utils_helper'

module Lich
  module Util
    module Update
      # Cleaner for Lich Update
      class Cleaner
        # Initialize a new Cleaner
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
        end

        # Check if Update module was loaded from this path
        # @param path [String] the path to check
        # @return [Boolean] true if the module was loaded from this path
        def module_loaded_from_path?(path)
          # Delegate to shared FileUtils module
          Lich::Util::Update::FileUtilsHelper.module_loaded_from_path?(path, @logger)
        end

        # Clean up old lib instance of update.rb
        # @param lib_dir [String] the lib directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_old_update_rb(lib_dir)
          # Delegate to shared FileUtils module
          Lich::Util::Update::FileUtilsHelper.cleanup_old_update_rb(lib_dir, @logger)
        end

        # Clean up temporary files
        # @param temp_dir [String] the temporary directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_temp_files(temp_dir)
          # Delegate to shared FileUtils module with nil filename for general cleanup
          Lich::Util::Update::FileUtilsHelper.cleanup_temp_files(temp_dir, nil, @logger)
        end

        # Clean up old snapshots
        # @param backup_dir [String] the backup directory
        # @param keep [Integer] the number of snapshots to keep
        # @return [Boolean] true if cleanup was successful
        def cleanup_old_snapshots(backup_dir, keep = 5)
          begin
            # Find all snapshot directories
            snapshots = Dir.glob(File.join(backup_dir, "L5-snapshot-*")).sort

            if snapshots.size <= keep
              @logger.info("Found #{snapshots.size} snapshots, keeping all of them")
              return true
            end

            # Determine which snapshots to remove
            to_remove = snapshots[0...(snapshots.size - keep)]

            @logger.info("Found #{snapshots.size} snapshots, removing #{to_remove.size} old ones")

            # Remove old snapshots
            to_remove.each do |snapshot|
              FileUtils.remove_dir(snapshot)
              @logger.info("Removed old snapshot: #{snapshot}")
            end

            @logger.success("Old snapshots cleaned up successfully")
            true
          rescue => e
            @logger.error("Failed to clean up old snapshots: #{e.message}")
            false
          end
        end

        # Perform a full cleanup
        # @param lib_dir [String] the lib directory
        # @param temp_dir [String] the temporary directory
        # @param backup_dir [String] the backup directory
        # @param keep_snapshots [Integer] the number of snapshots to keep
        # @return [Boolean] true if all cleanups were successful
        def cleanup_all(lib_dir, temp_dir, backup_dir, keep_snapshots = 5)
          @logger.info("Performing full cleanup...")

          old_update_cleaned = cleanup_old_update_rb(lib_dir)
          temp_files_cleaned = cleanup_temp_files(temp_dir)
          snapshots_cleaned = cleanup_old_snapshots(backup_dir, keep_snapshots)

          if old_update_cleaned && temp_files_cleaned && snapshots_cleaned
            @logger.success("Full cleanup completed successfully")
            true
          else
            @logger.warn("Full cleanup completed with some issues")
            false
          end
        end
      end
    end
  end
end
