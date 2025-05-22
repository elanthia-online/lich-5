# frozen_string_literal: true

require_relative 'error'
require_relative 'config'

module Lich
  module Util
    module Update
      # Version management for Lich Update
      class Version
        include Comparable

        attr_reader :version_string

        # Initialize a new Version object
        # @param version_string [String] the version string to parse
        # @raise [VersionError] if the version is not supported
        def initialize(version_string)
          @version_string = normalize_version(version_string)
          validate_version
        end

        # Normalize the version string by removing 'v' prefix if present
        # @param version [String] the version string to normalize
        # @return [String] the normalized version string
        def normalize_version(version)
          version.to_s.sub(/^v/, '')
        end

        # Validate that the version is supported
        # @raise [VersionError] if the version is not supported
        def validate_version
          unless @version_string.empty?
            if Gem::Version.new(@version_string) < Gem::Version.new(Config::MINIMUM_SUPPORTED_VERSION)
              raise VersionError,
                    "Version #{@version_string} is not supported. " \
                    "Minimum supported version is #{Config::MINIMUM_SUPPORTED_VERSION}"
            end
          end
        end

        # Compare this version with another version
        # Required method for Comparable mixin
        # @param other [String, Version] the version to compare with
        # @return [Integer] -1, 0, or 1 if this version is less than, equal to, or greater than other
        def <=>(other)
          other_version = other.is_a?(Version) ? other.version_string : normalize_version(other)
          Gem::Version.new(@version_string) <=> Gem::Version.new(other_version)
        end

        # Convert this version to a string
        # @return [String] the version string
        def to_s
          @version_string
        end
      end
    end
  end
end
