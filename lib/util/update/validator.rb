# frozen_string_literal: true

require_relative 'error'
require_relative 'config'
require_relative 'version'
require_relative 'github'

module Lich
  module Util
    module Update
      # Validator for Lich Update
      class Validator
        # Initialize a new Validator
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
        end

        # Validate a URL
        # @param url [String] the URL to validate
        # @return [Boolean] true if the URL is valid and accessible
        def validate_url(url)
          begin
            parsed_url = URI(url)
            response = Net::HTTP.get_response(parsed_url)

            if response.code[0, 1] == "2" || response.code[0, 1] == "3"
              true
            else
              @logger.error("URL #{url} returned status code #{response.code}")
              false
            end
          rescue => e
            @logger.error("Failed to validate URL #{url}: #{e.message}")
            false
          end
        end

        # Validate a file type
        # @param type [String, Symbol] the file type to validate
        # @return [Symbol] the normalized file type
        # @raise [ValidationError] if the file type is not valid
        def validate_file_type(type)
          normalized_type = normalize_file_type(type)

          unless [:script, :lib, :data].include?(normalized_type)
            raise ValidationError, "Invalid file type: #{type}. Must be one of: script, lib, data"
          end

          normalized_type
        end

        # Validate a file extension
        # @param type [Symbol] the file type
        # @param file [String] the file name
        # @return [Boolean] true if the file extension is valid for the type
        def validate_file_extension(type, file)
          valid_extensions = Config::VALID_EXTENSIONS[type]

          valid_extensions.any? { |ext| file.end_with?(ext) }
        end

        # Validate a version
        # @param version [String] the version to validate
        # @return [Version] the validated version
        # @raise [VersionError] if the version is not valid
        def validate_version(version)
          Version.new(version)
        end

        # Validate that a version is supported for backrev
        # @param version [String, Version] the version to validate
        # @return [Boolean] true if the version is supported
        def validate_backrev_version(version)
          version_obj = version.is_a?(Version) ? version : Version.new(version)

          if version_obj < Config::MINIMUM_SUPPORTED_VERSION
            @logger.error("Version #{version_obj} is not supported for backrev. " \
            "Minimum supported version is #{Config::MINIMUM_SUPPORTED_VERSION}")
            false
          else
            true
          end
        end

        private

        # Normalize a file type
        # @param type [String, Symbol] the file type to normalize
        # @return [Symbol] the normalized file type
        def normalize_file_type(type)
          case type.to_s.downcase
          when 'script'
            :script
          when 'lib', 'library'
            :lib
          when 'data'
            :data
          else
            type.to_sym
          end
        end
      end
    end
  end
end
