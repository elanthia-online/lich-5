# frozen_string_literal: true

require 'rubygems/package'
require 'open-uri'
require 'zlib'
require_relative 'error'
require_relative 'config'
require_relative 'version'
require_relative 'logger'
require_relative 'file_manager'
require_relative 'github'

module Lich
  module Util
    module Update
      # Installer for Lich Update
      class Installer
        # @return [Version] the current version
        attr_reader :current_version

        # Initialize a new Installer
        # @param logger [Logger] the logger to use
        # @param file_manager [FileManager] the file manager to use
        # @param github [GitHub] the GitHub client to use
        def initialize(logger, file_manager, github)
          @logger = logger
          @file_manager = file_manager
          @github = github
          @current_version = nil
          @update_to_version = nil
          @back_rev = false
        end

        # Set the current version
        # @param version [String] the current version
        def current_version=(version)
          @current_version = Version.new(version)
        end

        # Check if an update is available without performing the update
        # @param tag [String] the release tag to check (latest, beta, dev, alpha, or specific version)
        # @return [Array<Boolean, String>] [true, message] if update is available, [false, error_message] otherwise
        def check_update_available(tag)
          begin
            # Fetch release information
            release = @github.fetch_release_info(tag)
            update_to_version = Version.new(@github.get_version(release)) unless release.nil?
            return [false, "Remaining on current #{@current_version} Lich installation."] if release.nil?

            # Check if update is necessary
            if @current_version && update_to_version <= @current_version && !@back_rev
              return [false, "Lich version #{@current_version} is already up to date."]
            end

            # Update is available
            return [true, "Update available: #{update_to_version}"]
          rescue => e
            @logger.error("Failed to check for update: #{e.message}")
            return [false, "Failed to check for update: #{e.message}"]
          end
        end

        # Check if a file update is available without performing the update
        # @param type [String] the file type (script, lib, data)
        # @param file [String] the file to check
        # @param tag [String] the version to check (latest, beta, or specific version)
        # @return [Array<Boolean, String>] [true, message] if update is available, [false, error_message] otherwise
        def check_file_update_available(type, file, tag = 'production')
          begin
            type_sym = type.to_sym

            # Determine the remote repository URL
            remote_repo = case type_sym
                          when :script
                            if file.downcase == 'dependency.lic'
                              Config::REMOTE_REPOS[:script][:dependency]
                            else
                              Config::REMOTE_REPOS[:script][:default]
                            end
                          when :data
                            Config::REMOTE_REPOS[:data]
                          when :lib
                            case tag
                            when 'production'
                              Config::REMOTE_REPOS[:lib][:production]
                            when 'beta'
                              Config::REMOTE_REPOS[:lib][:beta]
                            else
                              # For specific versions, construct the URL
                              version_str = Version.new(tag).to_s
                              "https://raw.githubusercontent.com/#{Config::GITHUB_REPO}/refs/tags/v#{version_str}/lib"
                            end
                          else
                            return [false, "Invalid file type: #{type}"]
                          end

            # Check if the file exists remotely
            file_url = "#{remote_repo}/#{file}"

            # Try to access the file URL to verify it exists
            URI.parse(file_url).open.read

            # If we get here, the file exists remotely
            return [true, "Update available for #{file}"]
          rescue OpenURI::HTTPError => e
            if e.message.include?('404')
              return [false, "File not found: #{file}"]
            else
              return [false, "Error checking file: #{e.message}"]
            end
          rescue => e
            @logger.error("Failed to check file update: #{e.message}")
            return [false, "Failed to check file update: #{e.message}"]
          end
        end

        # Install a specific version of Lich
        # @param tag [String] the release tag to install (latest, beta, dev, alpha, or specific version)
        # @param lich_dir [String] the Lich directory
        # @param backup_dir [String] the backup directory
        # @param script_dir [String] the script directory
        # @param lib_dir [String] the lib directory
        # @param data_dir [String] the data directory
        # @param temp_dir [String] the temporary directory
        # @param options [Hash] additional options
        # @option options [Boolean] :confirm whether to confirm the installation
        # @option options [Boolean] :create_snapshot whether to create a snapshot before installation
        # @return [Boolean] true if the installation was successful
        def install(tag, lich_dir, backup_dir, script_dir, lib_dir, data_dir, temp_dir, options = {})
          options = {
            confirm: true,
            create_snapshot: true
          }.merge(options)

          # Fetch release information
          release = @github.fetch_release_info(tag)
          @update_to_version = Version.new(@github.get_version(release))

          # Check if update is necessary
          if @current_version && @update_to_version <= @current_version && !@back_rev
            @logger.info("Lich version #{@current_version} is good. Enjoy!")
            return true
          end

          # Confirm installation if required
          if options[:confirm] && !confirm_installation
            @logger.info("Installation cancelled by user")
            return false
          end

          # Create snapshot if required
          if options[:create_snapshot]
            @logger.info("Processing update. First we will create a snapshot of your Lich files before the update.")
            @file_manager.create_snapshot(lich_dir, backup_dir, script_dir, lib_dir, data_dir, Config::CORE_SCRIPTS, Config::USER_DATA_FILES)
          end

          # Download and extract the release
          download_url = @github.get_download_url(release)
          filename = "lich5-#{@update_to_version}"

          @logger.blank_line
          @logger.info("Downloading Lich5 version #{@update_to_version}")
          @logger.blank_line

          # Download the release archive
          archive_path = File.join(temp_dir, "#{filename}.tar.gz")
          download_file(download_url, archive_path)

          # Extract the release archive
          extract_dir = File.join(temp_dir, filename)
          FileUtils.mkdir_p(extract_dir)
          extract_archive(archive_path, extract_dir)

          # Find the extracted directory
          extracted_dirs = Dir.children(extract_dir)
          if extracted_dirs.empty?
            raise InstallationError, "Failed to extract release archive"
          end

          # Move the extracted files to the temporary directory
          extracted_path = File.join(extract_dir, extracted_dirs[0])
          FileUtils.cp_r(extracted_path, temp_dir)
          FileUtils.remove_dir(extract_dir)
          FileUtils.mv(File.join(temp_dir, extracted_dirs[0]), File.join(temp_dir, filename))

          # Update the files
          update_files(lich_dir, lib_dir, script_dir, data_dir, temp_dir, filename)

          # Clean up temporary files
          @file_manager.cleanup_temp_files(temp_dir, filename)

          @logger.blank_line
          @logger.success("Lich5 has been updated to Lich5 version #{@update_to_version}")
          @logger.info("You should exit the game, then log back in. This will start the game")
          @logger.info("with your updated Lich. Enjoy!")

          true
        end

        # Update core data and scripts
        # @param script_dir [String] the script directory
        # @param data_dir [String] the data directory
        # @param game_type [String] the game type (gs or dr)
        def update_core_data_and_scripts(script_dir, data_dir, game_type = 'gs')
          unless ['gs', 'dr'].include?(game_type.downcase)
            @logger.error("Invalid game type, unsure what scripts to update")
            return false
          end

          # Update data files
          Config::SENSITIVE_DATA_FILES.each do |file|
            # Backup existing data file
            if File.exist?(File.join(data_dir, file))
              backup_filename = "#{file.sub(/\.[^.]+$/, '')}-#{Time.now.to_i}#{File.extname(file)}"
              FileUtils.cp(
                File.join(data_dir, file),
                File.join(data_dir, backup_filename)
              )
              @logger.info("The prior version of #{file} was renamed to #{backup_filename}.")
            end

            # Update the data file
            update_file('data', file, data_dir)
          end

          # Update core scripts
          Config::CORE_SCRIPTS.each do |script|
            update_file('script', script, script_dir)
          end

          # Update game-specific scripts
          Config::GAME_SPECIFIC_SCRIPTS[game_type.downcase].each do |script|
            update_file('script', script, script_dir)
          end

          true
        end

        # Update a specific file
        # @param type [String] the file type (script, lib, data)
        # @param file [String] the file to update
        # @param location [String] the directory to update the file in
        # @param version [String] the version to update to (latest, beta, or specific version)
        # @return [Boolean] true if the file was updated successfully
        def update_file(type, file, location, version = 'production')
          type_sym = type.to_sym

          # Determine the remote repository URL
          remote_repo = case type_sym
                        when :script
                          if file.downcase == 'dependency.lic'
                            Config::REMOTE_REPOS[:script][:dependency]
                          else
                            Config::REMOTE_REPOS[:script][:default]
                          end
                        when :data
                          Config::REMOTE_REPOS[:data]
                        when :lib
                          case version
                          when 'production'
                            Config::REMOTE_REPOS[:lib][:production]
                          when 'beta'
                            Config::REMOTE_REPOS[:lib][:beta]
                          else
                            # For specific versions, construct the URL
                            version_str = Version.new(version).to_s
                            "https://raw.githubusercontent.com/#{Config::GITHUB_REPO}/refs/tags/v#{version_str}/lib"
                          end
                        else
                          @logger.error("Invalid file type: #{type}")
                          return false
                        end

          # Update the file
          @file_manager.update_file(type_sym, file, location, remote_repo)
        end

        # Update to a specific version
        # @param tag [String] the release tag to update to (latest, beta, dev, alpha, or specific version)
        # @return [Array<Boolean, String>] [success, message] tuple
        def update(tag)
          begin
            # Fetch release information
            release = @github.fetch_release_info(tag)
            @update_to_version = Version.new(@github.get_version(release))

            # Check if update is necessary
            if @current_version && @update_to_version <= @current_version && !@back_rev
              return [false, "Lich version #{@current_version} is already up to date."]
            end

            # Perform the update
            success = install(
              tag,
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:data],
              Config::DIRECTORIES[:temp]
            )

            if success
              return [true, "Successfully updated to version #{@update_to_version}"]
            else
              return [false, "Failed to update to version #{@update_to_version}"]
            end
          rescue => e
            @logger.error("Update failed: #{e.message}")
            return [false, "Update failed: #{e.message}"]
          end
        end

        # Revert to a previous snapshot
        # @return [Array<Boolean, String>] [success, message] tuple
        def revert
          begin
            success = @file_manager.revert_to_snapshot(
              Config::DIRECTORIES[:lich],
              Config::DIRECTORIES[:backup],
              Config::DIRECTORIES[:script],
              Config::DIRECTORIES[:lib],
              Config::DIRECTORIES[:data]
            )

            if success
              return [true, "Successfully reverted to previous snapshot"]
            else
              return [false, "Failed to revert to previous snapshot"]
            end
          rescue => e
            @logger.error("Revert failed: #{e.message}")
            return [false, "Revert failed: #{e.message}"]
          end
        end

        private

        # Confirm the installation with the user
        # @return [Boolean] true if the user confirms the installation
        def confirm_installation
          @logger.info("You are about to update Lich5. This will create a snapshot of your current installation.")
          @logger.info("Do you want to continue? (Y/N)")

          return Lich::Util::Update.get_user_confirmation(@logger)
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
            true
          rescue => e
            @logger.error("Failed to download file from #{url}: #{e.message}")
            false
          end
        end

        # Extract a tar.gz archive
        # @param archive_path [String] the path to the archive
        # @param destination [String] the directory to extract to
        def extract_archive(archive_path, destination)
          begin
            FileUtils.mkdir_p(destination)
            File.open(archive_path, "rb") { |f| Gem::Package.new("").extract_tar_gz(f, destination) }
            true
          rescue => e
            @logger.error("Failed to extract archive #{archive_path}: #{e.message}")
            false
          end
        end

        # Update the Lich files
        # @param lich_dir [String] the Lich directory
        # @param lib_dir [String] the lib directory
        # @param script_dir [String] the script directory
        # @param data_dir [String] the data directory
        # @param temp_dir [String] the temporary directory
        # @param filename [String] the release filename
        def update_files(lich_dir, lib_dir, script_dir, data_dir, temp_dir, filename)
          @logger.info("Copying updated lich files to their locations.")

          # Delete all existing lib files
          FileUtils.rm_rf(Dir.glob(File.join(lib_dir, "*")))

          # Copy new lib files
          FileUtils.copy_entry(File.join(temp_dir, filename, "lib"), lib_dir)

          @logger.blank_line
          @logger.info("All Lich lib files have been updated.")
          @logger.blank_line

          # Update core data and scripts
          update_core_data_and_scripts(script_dir, data_dir, 'gs')

          # Update the main Lich file
          lich_to_update = File.join(lich_dir, File.basename($PROGRAM_NAME || 'lich.rbw'))
          update_to_lich = File.join(temp_dir, filename, "lich.rbw")

          File.open(update_to_lich, 'rb') do |r|
            File.open(lich_to_update, 'wb') do |w|
              w.write(r.read)
            end
          end
        end
      end
    end
  end
end
