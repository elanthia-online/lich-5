# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require 'net/http'
require_relative 'error'
require_relative 'logger'
require_relative 'config'
require_relative 'file_utils_helper'

module Lich
  module Util
    module Update
      # File manager for Lich Update
      class FileManager
        # Initialize a new FileManager
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
        end

        # Create a snapshot of the current Lich installation
        # @param lich_dir [String] the Lich directory
        # @param backup_dir [String] the backup directory
        # @param script_dir [String] the script directory
        # @param lib_dir [String] the lib directory
        # @param core_scripts [Array<String>] the core script files to backup
        # @return [String] the path to the created snapshot directory
        def create_snapshot(lich_dir, backup_dir, script_dir, lib_dir, core_scripts)
          @logger.info('Creating a snapshot of current Lich core files ONLY.')
          @logger.blank_line
          @logger.info('You may also wish to copy your entire Lich5 folder to')
          @logger.info('another location for additional safety, after any')
          @logger.info('additional requested updates are completed.')

          # Create snapshot directory
          snapshot_subdir = File.join(backup_dir, "L5-snapshot-#{Time.now.strftime('%Y-%m-%d-%H-%M-%S')}")
          FileUtils.mkdir_p(snapshot_subdir)

          # Backup main Lich file
          program_name = File.basename($PROGRAM_NAME || 'lich.rbw')
          FileUtils.cp(File.join(lich_dir, program_name), File.join(snapshot_subdir, program_name))

          # Backup lib directory
          FileUtils.mkdir_p(File.join(snapshot_subdir, 'lib'))
          FileUtils.cp_r(lib_dir, snapshot_subdir)

          # Backup core scripts
          FileUtils.mkdir_p(File.join(snapshot_subdir, 'scripts'))
          core_scripts.each do |file|
            source_file = File.join(script_dir, file)
            if File.exist?(source_file)
              FileUtils.cp(source_file, File.join(snapshot_subdir, 'scripts', file))
            end
          end

          @logger.blank_line
          @logger.info('Current Lich ecosystem files (only) backed up to:')
          @logger.info("    #{snapshot_subdir}")

          snapshot_subdir
        end

        # Clean up temporary files
        # @param temp_dir [String] the temporary directory
        # @param filename [String] the filename to clean up
        def cleanup_temp_files(temp_dir, filename)
          # Delegate to shared FileUtils module
          Lich::Util::Update::FileUtilsHelper.cleanup_temp_files(temp_dir, filename, @logger)
        end

        # Clean up old lib instance of update.rb
        # @param lib_dir [String] the lib directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_old_update_rb(lib_dir)
          # Delegate to shared FileUtils module
          Lich::Util::Update::FileUtilsHelper.cleanup_old_update_rb(lib_dir, @logger)
        end

        # Update a file from a remote repository
        # @param type [Symbol] the type of file (:script, :lib, :data)
        # @param file [String] the file to update
        # @param location [String] the local directory to update the file in
        # @param remote_repo [String] the remote repository URL
        # @return [Boolean] true if the file was updated successfully
        def update_file(type, file, location, remote_repo)
          # Validate file extension using shared method
          unless Lich::Util::Update::FileUtilsHelper.valid_extension?(type, file)
            @logger.error("The requested file #{file} has an incorrect extension.")
            @logger.info("Valid extensions are #{Config::VALID_EXTENSIONS[type].join(', ')} for #{type} files.")
            return false
          end

          # Construct remote URL
          remote_url = File.join(remote_repo, file)

          # Check if file exists at remote URL using shared method
          unless Lich::Util::Update::FileUtilsHelper.file_exists_at_url?(remote_url, @logger)
            @logger.error("The file #{file} does not exist at #{remote_url}")
            return false
          end

          # Delete existing file if it exists
          local_path = File.join(location, file)
          FileUtils.rm(local_path) if File.exist?(local_path)

          # Download and save the file using shared method
          begin
            Lich::Util::Update::FileUtilsHelper.download_file(remote_url, local_path, @logger)
            @logger.success("#{file} has been updated.")
            true
          rescue => e
            @logger.error("Failed to update #{file}: #{e.message}")
            # Clean up any partial downloads
            FileUtils.rm(local_path) if File.exist?(local_path)
            false
          end
        end
      end
    end
  end
end
