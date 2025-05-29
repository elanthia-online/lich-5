# frozen_string_literal: true

require_relative 'error'
require_relative 'config'
require_relative 'version'

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

        # Validate a URL with proper SSL validation for HTTPS sites
        # @param url [String] the URL to validate
        # @return [Boolean] true if the URL is valid and accessible
        def validate_url(url)
          begin
            parsed_url = URI(url)
            response = make_http_request(parsed_url)

            # Check final response code
            if response && response.code.start_with?('2')
              true
            else
              @logger.error("URL #{url} returned status code #{response.code}")
              false
            end
          rescue OpenSSL::SSL::SSLError => e
            @logger.error("SSL validation failed for URL #{url}: #{e.message}")
            false
          rescue Net::OpenTimeout, Net::ReadTimeout => e
            @logger.error("Timeout occurred while validating URL #{url}: #{e.message}")
            false
          rescue URI::InvalidURIError => e
            @logger.error("Invalid URL format for #{url}: #{e.message}")
            false
          rescue => e
            @logger.error("Failed to validate URL #{url}: #{e.message}")
            false
          end
        end

        # Make an HTTP request with proper SSL validation and redirect handling
        # @param url [URI] the parsed URL to request
        # @param redirect_limit [Integer] the number of redirects to follow
        # @return [Net::HTTPResponse] the HTTP response
        def make_http_request(url, redirect_limit = 5)
          return nil if redirect_limit <= 0

          http = Net::HTTP.new(url.host, url.port)

          # Configure SSL for HTTPS URLs
          if url.scheme == 'https'
            configure_ssl(http)
          end

          # Set reasonable timeouts
          http.open_timeout = 10 # seconds
          http.read_timeout = 10 # seconds

          # Make the request
          request = Net::HTTP::Get.new(url.request_uri)
          response = http.request(request)

          # Handle redirects
          if ['301', '302', '303', '307', '308'].include?(response.code) && redirect_limit > 0
            redirect_url = URI(response['location'])
            return make_http_request(redirect_url, redirect_limit - 1)
          end

          response
        end

        # Configure SSL settings for an HTTP connection
        # @param http [Net::HTTP] the HTTP connection to configure
        def configure_ssl(http)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.cert_store = OpenSSL::X509::Store.new
          http.cert_store.set_default_paths # Use system's certificate store
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
