# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require 'net/http'
require_relative 'error'
require_relative 'logger'
require_relative 'config'

module Lich
  module Util
    module Update
      # Shared file utilities for Lich Update
      module FileUtilsHelper
        class << self
          # Check if Update module was loaded from this path
          # @param path [String] the path to check
          # @param logger [Logger] the logger to use
          # @return [Boolean] true if the module was loaded from this path
          def module_loaded_from_path?(path, logger = nil)
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
              logger&.error("Error checking if module was loaded from path: #{e.message}")
              # Default to true if there's an error
              return true
            end
          end

          # Clean up old lib instance of update.rb
          # @param lib_dir [String] the lib directory
          # @param logger [Logger] the logger to use
          # @return [Boolean] true if cleanup was successful
          def cleanup_old_update_rb(lib_dir, logger)
            old_update_path = File.join(lib_dir, 'update.rb')

            if File.exist?(old_update_path)
              begin
                if module_loaded_from_path?(old_update_path, logger)
                  logger.info("Found old update.rb at #{old_update_path}")
                  logger.info("Removing old update.rb...")

                  FileUtils.rm(old_update_path)

                  logger.success("Old update.rb removed successfully")
                  return true
                else
                  logger.info("Old update.rb found at #{old_update_path}, but Lich::Util::Update module is not loaded")
                  return false
                end
              rescue => e
                logger.error("Failed to remove old update.rb: #{e.message}")
                return false
              end
            else
              logger.info("No old update.rb found at #{old_update_path}")
              return true
            end
          end

          # Clean up temporary files
          # @param temp_dir [String] the temporary directory
          # @param filename [String] the specific filename to clean up (optional)
          # @param logger [Logger] the logger to use
          # @return [Boolean] true if cleanup was successful
          def cleanup_temp_files(temp_dir, filename = nil, logger = nil)
            begin
              if filename
                # Clean up specific file
                temp_path = File.join(temp_dir, filename)
                FileUtils.remove_dir(temp_path) if Dir.exist?(temp_path)

                # Remove temporary archive if it exists
                temp_archive = "#{temp_path}.tar.gz"
                FileUtils.rm(temp_archive) if File.exist?(temp_archive)
                
                logger&.info("Cleaned up temporary files for #{filename}")
                return true
              else
                # Find all lich5-* directories and files in the temp directory
                temp_files = Dir.glob(File.join(temp_dir, "lich5-*"))

                if temp_files.empty?
                  logger&.info("No temporary files found to clean up")
                  return true
                end

                logger&.info("Found #{temp_files.size} temporary files to clean up")

                # Remove each temporary file or directory
                temp_files.each do |file|
                  if File.directory?(file)
                    FileUtils.remove_dir(file)
                    logger&.info("Removed temporary directory: #{file}")
                  else
                    FileUtils.rm(file)
                    logger&.info("Removed temporary file: #{file}")
                  end
                end

                logger&.success("Temporary files cleaned up successfully")
                return true
              end
            rescue => e
              logger&.error("Failed to clean up temporary files: #{e.message}")
              return false
            end
          end

          # Check if a file has a valid extension for its type
          # @param type [Symbol] the type of file (:script, :lib, :data)
          # @param file [String] the file to check
          # @return [Boolean] true if the file has a valid extension
          def valid_extension?(type, file)
            Config::VALID_EXTENSIONS[type].any? { |ext| file.end_with?(ext) }
          end

          # Check if a file exists at a URL
          # @param url [String] the URL to check
          # @param logger [Logger] the logger to use
          # @return [Boolean] true if the file exists
          def file_exists_at_url?(url, logger = nil)
            begin
              uri = URI(url)
              response = Net::HTTP.get_response(uri)
              return response.code.to_i >= 200 && response.code.to_i < 400
            rescue => e
              logger&.error("Error checking if file exists at #{url}: #{e.message}")
              return false
            end
          end

          # Download a file from a URL
          # @param url [String] the URL to download from
          # @param destination [String] the local path to save the file to
          # @param logger [Logger] the logger to use
          def download_file(url, destination, logger = nil)
            begin
              FileUtils.mkdir_p(File.dirname(destination))
              File.open(destination, 'wb') do |file|
                file.write URI.parse(url).open.read
              end
            rescue => e
              error_msg = "Failed to download file from #{url}: #{e.message}"
              logger&.error(error_msg)
              raise Error, error_msg
            end
          end
        end
      end
    end
  end
end
