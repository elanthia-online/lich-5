# frozen_string_literal: true

require_relative 'error'
require_relative 'logger'

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
        def module_loaded_from_path?(path)
          begin
            if defined?(Lich::Util::Update)
              # Get the source location of the module
              source_location = nil

              # Try to find a method in the module and get its source location
              if Lich::Util::Update.methods(false).any?
                method_name = Lich::Util::Update.methods(false).first
                source_location = Lich::Util::Update.method(method_name).source_location&.first
              end

              # If we couldn't find a method, try constants
              if source_location.nil? && Lich::Util::Update.constants.any?
                const_name = Lich::Util::Update.constants.first
                const_obj = Lich::Util::Update.const_get(const_name)
                if const_obj.is_a?(Module) || const_obj.is_a?(Class)
                  if const_obj.methods(false).any?
                    method_name = const_obj.methods(false).first
                    source_location = const_obj.method(method_name).source_location&.first
                  end
                end
              end

              # Check if the source location matches the path
              if source_location && source_location.start_with?(File.dirname(path))
                return true
              end
            end

            # Default to true if we can't determine for sure
            # This is safer than not cleaning up
            return true
          rescue => e
            @logger.error("Error checking if module was loaded from path: #{e.message}")
            # Default to true if there's an error
            return true
          end
        end

        # Clean up old lib instance of update.rb
        # @param lib_dir [String] the lib directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_old_update_rb(lib_dir)
          old_update_path = File.join(lib_dir, 'update.rb')

          if File.exist?(old_update_path)
            begin
              if module_loaded_from_path?(old_update_path)
                @logger.info("Found old update.rb at #{old_update_path}")
                @logger.info("Removing old update.rb...")

                FileUtils.rm(old_update_path)

                @logger.success("Old update.rb removed successfully")
                return true
              else
                @logger.info("Old update.rb found at #{old_update_path}, but Lich::Util::Update module is not loaded")
                return false
              end
            rescue => e
              @logger.error("Failed to remove old update.rb: #{e.message}")
              return false
            end
          else
            @logger.info("No old update.rb found at #{old_update_path}")
            return true
          end
        end

        # Clean up temporary files
        # @param temp_dir [String] the temporary directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_temp_files(temp_dir)
          begin
            # Find all lich5-* directories and files in the temp directory
            temp_files = Dir.glob(File.join(temp_dir, "lich5-*"))

            if temp_files.empty?
              @logger.info("No temporary files found to clean up")
              return true
            end

            @logger.info("Found #{temp_files.size} temporary files to clean up")

            # Remove each temporary file or directory
            temp_files.each do |file|
              if File.directory?(file)
                FileUtils.remove_dir(file)
                @logger.info("Removed temporary directory: #{file}")
              else
                FileUtils.rm(file)
                @logger.info("Removed temporary file: #{file}")
              end
            end

            @logger.success("Temporary files cleaned up successfully")
            true
          rescue => e
            @logger.error("Failed to clean up temporary files: #{e.message}")
            false
          end
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
