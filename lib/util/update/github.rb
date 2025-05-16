# frozen_string_literal: true

require 'json'
require 'open-uri'
require_relative 'error'
require_relative 'config'
require_relative 'version'

module Lich
  module Util
    module Update
      # GitHub API client for Lich Update
      class GitHub
        # Initialize a new GitHub client
        # @param logger [Logger] the logger to use
        def initialize(logger)
          @logger = logger
        end

        # Fetch release information from GitHub
        # @param tag [String] the release tag to fetch (latest, beta, dev, alpha, or specific version)
        # @return [Hash] the release information
        # @raise [NetworkError] if the request fails
        # @raise [VersionError] if the requested version is not supported
        def fetch_release_info(tag)
          case tag
          when 'latest'
            fetch_latest_release
          when 'beta'
            fetch_beta_release
          when 'dev', 'alpha'
            fetch_dev_release
          else
            # Assume tag is a specific version
            fetch_specific_version(tag)
          end
        end

        # Get the download URL for a release
        # @param release [Hash] the release information
        # @return [String] the download URL
        # @raise [Error] if the download URL cannot be found
        def get_download_url(release)
          assets = release['assets']
          requested_asset = assets.find { |x| x['name'] =~ /lich-5.tar.gz/ }

          if requested_asset.nil?
            raise Error, "Could not find download URL for release #{release['tag_name']}"
          end

          requested_asset.fetch('browser_download_url')
        end

        # Get the version from a release
        # @param release [Hash] the release information
        # @return [String] the version
        def get_version(release)
          release['tag_name'].sub('v', '')
        end

        # Get the release notes from a release
        # @param release [Hash] the release information
        # @return [String] the release notes
        def get_release_notes(release)
          release['body'].to_s.gsub(/\#\# What's Changed.+$/m, '')
        end

        private

        # Fetch the latest release from GitHub
        # @return [Hash] the release information
        # @raise [NetworkError] if the request fails
        def fetch_latest_release
          url = "#{Config::GITHUB_API_URL}/latest"
          fetch_from_url(url)
        end

        # Fetch the beta release from GitHub
        # @return [Hash] the release information
        # @raise [NetworkError] if the request fails
        def fetch_beta_release
          url = Config::GITHUB_API_URL
          releases = fetch_from_url(url)
          # Assumption: Beta release is the first pre-release in the list
          beta_release = releases.find { |r| r['prerelease'] == true }

          if beta_release.nil?
            # If no pre-release is found, fall back to the latest release
            @logger.warn("No beta release found, using latest release instead")
            fetch_latest_release
          else
            beta_release
          end
        end

        # Fetch the dev/alpha release from GitHub
        # @return [Hash] the release information
        # @raise [NetworkError] if the request fails
        def fetch_dev_release
          url = Config::GITHUB_API_URL
          releases = fetch_from_url(url)
          # Assumption: Dev/alpha release is the first draft release in the list
          dev_release = releases.find { |r| r['draft'] == true }

          if dev_release.nil?
            # If no draft release is found, fall back to the beta release
            @logger.warn("No dev/alpha release found, using beta release instead")
            fetch_beta_release
          else
            dev_release
          end
        end

        # Fetch a specific version from GitHub
        # @param version_tag [String] the version tag to fetch
        # @return [Hash] the release information
        # @raise [NetworkError] if the request fails
        # @raise [VersionError] if the requested version is not supported
        def fetch_specific_version(version_tag)
          # Normalize version tag
          version = Version.new(version_tag)

          # Fetch all releases
          url = Config::GITHUB_API_URL
          releases = fetch_from_url(url)

          # Find the requested version
          requested_release = releases.find { |r| r['tag_name'] == "v#{version}" }

          if requested_release.nil?
            raise VersionError, "Version #{version} is not a valid Lich release"
          end

          requested_release
        end

        # Fetch data from a URL
        # @param url [String] the URL to fetch from
        # @return [Hash, Array<Hash>] the parsed JSON response
        # @raise [NetworkError] if the request fails
        def fetch_from_url(url)
          begin
            response = URI.parse(url).open.read
            JSON.parse(response)
          rescue => e
            raise NetworkError, "Failed to fetch data from #{url}: #{e.message}"
          end
        end
      end
    end
  end
end
