# frozen_string_literal: true

require_relative 'error'
require_relative 'config'
require_relative 'version'

module Lich
  module Util
    module Update
      # Tag support for Lich Update
      class TagSupport
        # Initialize a new TagSupport
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
        end

        # Validate a tag
        # @param tag [String] the tag to validate
        # @return [String] the normalized tag
        # @raise [ValidationError] if the tag is not valid
        def validate_tag(tag)
          if tag.nil? || tag.empty?
            raise ValidationError, "Tag cannot be empty"
          end

          normalized_tag = normalize_tag(tag)

          case normalized_tag
          when 'latest', 'beta', 'dev', 'alpha'
            # These are valid predefined tags
            normalized_tag
          else
            # Check if it's a valid version tag
            begin
              version = Version.new(normalized_tag)
              version.to_s
            rescue VersionError => e
              raise ValidationError, "Invalid tag: #{e.message}"
            end
          end
        end

        # Normalize a tag
        # @param tag [String] the tag to normalize
        # @return [String] the normalized tag
        def normalize_tag(tag)
          # Handle special cases
          case tag.to_s.downcase
          when '--latest', '-latest', 'latest'
            'latest'
          when '--beta', '-beta', 'beta', '--test', '-test', 'test'
            'beta'
          when '--dev', '-dev', 'dev'
            'dev'
          when '--alpha', '-alpha', 'alpha'
            'alpha'
          else
            # Handle version tags (e.g., v5.11.0, 5.11.0)
            if tag =~ /^v?(\d+\.\d+\.\d+(?:-[\w\d\.]+)?)$/
              $1
            else
              tag
            end
          end
        end

        # Get the tag description
        # @param tag [String] the tag
        # @return [String] the tag description
        def tag_description(tag)
          case normalize_tag(tag)
          when 'latest'
            "the latest stable release"
          when 'beta'
            "the latest beta release"
          when 'dev'
            "the latest development release"
          when 'alpha'
            "the latest alpha release"
          else
            "version #{tag}"
          end
        end

        # List available tags
        # @param github [GitHub] the GitHub client
        # @return [Array<String>] the available tags
        def list_available_tags(github)
          # Get all releases
          releases = github.fetch_from_url(Config::GITHUB_API_URL)

          # Extract tags
          tags = releases.map { |r| r['tag_name'].sub('v', '') }

          # Filter tags to only include those >= minimum supported version
          tags.select do |tag|
            begin
              Version.new(tag) >= Config::MINIMUM_SUPPORTED_VERSION
            rescue
              false
            end
          end
        end
      end
    end
  end
end
