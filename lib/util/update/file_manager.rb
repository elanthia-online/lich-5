# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require 'net/http'
require_relative 'error'
require_relative 'logger'

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
          # Remove temporary directory if it exists
          temp_path = File.join(temp_dir, filename)
          FileUtils.remove_dir(temp_path) if Dir.exist?(temp_path)

          # Remove temporary archive if it exists
          temp_archive = "#{temp_path}.tar.gz"
          FileUtils.rm(temp_archive) if File.exist?(temp_archive)
        end

        # Clean up old lib instance of update.rb
        # @param lib_dir [String] the lib directory
        # @return [Boolean] true if cleanup was successful
        def cleanup_old_update_rb(lib_dir)
          old_update_path = File.join(lib_dir, 'update.rb')

          if File.exist?(old_update_path)
            begin
              if Cleaner.module_loaded_from_path?(old_update_path)
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

        # Update a file from a remote repository
        # @param type [Symbol] the type of file (:script, :lib, :data)
        # @param file [String] the file to update
        # @param location [String] the local directory to update the file in
        # @param remote_repo [String] the remote repository URL
        # @return [Boolean] true if the file was updated successfully
        def update_file(type, file, location, remote_repo)
          # Validate file extension
          unless valid_extension?(type, file)
            @logger.error("The requested file #{file} has an incorrect extension.")
            @logger.info("Valid extensions are #{Config::VALID_EXTENSIONS[type].join(', ')} for #{type} files.")
            return false
          end

          # Construct remote URL
          remote_url = File.join(remote_repo, file)

          # Check if file exists at remote URL
          unless file_exists_at_url?(remote_url)
            @logger.error("The file #{file} does not exist at #{remote_url}")
            return false
          end

          # Delete existing file if it exists
          local_path = File.join(location, file)
          FileUtils.rm(local_path) if File.exist?(local_path)

          # Download and save the file
          begin
            download_file(remote_url, local_path)
            @logger.success("#{file} has been updated.")
            true
          rescue => e
            @logger.error("Failed to update #{file}: #{e.message}")
            # Clean up any partial downloads
            FileUtils.rm(local_path) if File.exist?(local_path)
            false
          end
        end

        private

        # Check if a file has a valid extension for its type
        # @param type [Symbol] the type of file (:script, :lib, :data)
        # @param file [String] the file to check
        # @return [Boolean] true if the file has a valid extension
        def valid_extension?(type, file)
          Config::VALID_EXTENSIONS[type].any? { |ext| file.end_with?(ext) }
        end

        # Check if a file exists at a URL
        # @param url [String] the URL to check
        # @return [Boolean] true if the file exists
        def file_exists_at_url?(url)
          begin
            uri = URI(url)
            response = Net::HTTP.get_response(uri)
            return response.code.to_i >= 200 && response.code.to_i < 400
          rescue => e
            @logger.error("Error checking if file exists at #{url}: #{e.message}")
            return false
          end
        end

        # Download a file from a URL
        # @param url [String] the URL to download from
        # @param destination [String] the local path to save the file to
        def download_file(url, destination)
          begin
            FileUtils.mkdir_p(File.dirname(destination))
            File.open(destination, 'wb') do |file|
              file.write URI.parse(url).open.read
            end
          rescue => e
            raise Error, "Failed to download file from #{url}: #{e.message}"
          end
        end
      end
    end
  end
end
