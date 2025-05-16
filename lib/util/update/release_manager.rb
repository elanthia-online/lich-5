# frozen_string_literal: true

require_relative 'error'
require_relative 'config'
require_relative 'version'
require_relative 'tag_support'
require_relative 'validator'
require_relative 'github'

module Lich
  module Util
    module Update
      # Release manager for Lich Update
      class ReleaseManager
        # Initialize a new ReleaseManager
        # @param logger [Logger] the logger to use
        # @param github [GitHub] the GitHub client to use
        # @param tag_support [TagSupport] the tag support to use
        # @param validator [Validator] the validator to use
        def initialize(logger, github, tag_support, validator)
          @logger = logger
          @github = github
          @tag_support = tag_support
          @validator = validator
        end

        # Get release information for a tag
        # @param tag [String] the tag to get release information for
        # @return [Hash] the release information
        # @raise [ValidationError] if the tag is not valid
        # @raise [NetworkError] if the request fails
        # @raise [VersionError] if the requested version is not supported
        def get_release_info(tag)
          # Validate and normalize the tag
          normalized_tag = @tag_support.validate_tag(tag)

          # Fetch release information
          release = @github.fetch_release_info(normalized_tag)

          # Extract release information
          version = @github.get_version(release)
          download_url = @github.get_download_url(release)
          release_notes = @github.get_release_notes(release)

          # Validate version for backrev
          if normalized_tag != 'latest' &&
             normalized_tag != 'beta' &&
             normalized_tag != 'dev' &&
             normalized_tag != 'alpha'
            unless @validator.validate_backrev_version(version)
              raise VersionError,
                    "Version #{version} is not supported for backrev. " \
                    "Minimum supported version is #{Config::MINIMUM_SUPPORTED_VERSION}"
            end
          end

          {
            tag: normalized_tag,
            version: version,
            download_url: download_url,
            release_notes: release_notes,
            is_backrev: normalized_tag != 'latest' &&
              normalized_tag != 'beta' &&
              normalized_tag != 'dev' &&
              normalized_tag != 'alpha'
          }
        end

        # Check if an update is available
        # @param current_version [String] the current version
        # @param tag [String] the tag to check
        # @return [Boolean] true if an update is available
        def update_available?(current_version, tag)
          # Get release information
          release_info = get_release_info(tag)

          # Compare versions
          current = Version.new(current_version)
          target = Version.new(release_info[:version])

          # If it's a backrev, we always allow the update
          if release_info[:is_backrev]
            return true
          end

          # Otherwise, only update if the target version is newer
          target > current
        end

        # Announce an update
        # @param current_version [String] the current version
        # @param tag [String] the tag to announce
        # @return [Boolean] true if an update is available
        def announce_update(current_version, tag)
          # Check if an update is available
          unless update_available?(current_version, tag)
            @logger.info("Lich version #{current_version} is good. Enjoy!")
            return false
          end

          # Get release information
          release_info = get_release_info(tag)

          # Announce the update
          @logger.blank_line
          @logger.bold("*** NEW VERSION AVAILABLE ***")
          @logger.blank_line
          @logger.blank_line
          @logger.blank_line
          @logger.info(release_info[:release_notes])
          @logger.blank_line
          @logger.blank_line
          @logger.bold("If you are interested in updating to #{@tag_support.tag_description(tag)}, " \
                       "run 'lich5-update --update' now.")
          @logger.blank_line

          true
        end

        # List available versions
        # @return [Array<String>] the available versions
        def list_available_versions
          @tag_support.list_available_tags(@github)
        end
      end
    end
  end
end
