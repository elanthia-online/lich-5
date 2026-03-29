# frozen_string_literal: true

=begin
  Resolves update channel names to git references.

  Determines the appropriate git ref (tag or branch) for stable and beta
  channels by querying GitHub releases and branches. Handles semantic
  versioning comparison to find the latest eligible beta.
=end

module Lich
  module Util
    module Update
      class ChannelResolver
        # @param client [GitHubClient] GitHub API client instance
        def initialize(client)
          @client = client
        end

        # Resolves channel symbol to git ref (tag or branch).
        #
        # @param channel [Symbol, String] :stable, :beta, or 'production'
        # @return [String, nil] git ref or nil
        def resolve_channel_ref(channel)
          case channel
          when :stable, 'production'
            STABLE_REF
          when :beta
            env = ENV['LICH_BETA_REF']
            return env unless env.nil? || env.empty?

            stable_tag = latest_stable_tag
            stable_major, stable_minor, stable_patch = major_minor_patch_from(stable_tag)
            return nil unless stable_major

            tag = latest_prerelease_tag_greater_than(stable_major, stable_minor, stable_patch)
            return tag if tag

            branch = latest_prefixed_branch_greater_than(BETA_BRANCH_PREFIX, stable_major, stable_minor, stable_patch)
            return branch if branch

            nil
          else
            STABLE_REF
          end
        end

        # Fetches latest stable (non-prerelease) tag from GitHub.
        #
        # @return [String, nil] tag name or nil
        def latest_stable_tag
          releases = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
          return nil unless releases.is_a?(Array)

          stable = releases.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| version_key(r['tag_name']) }
          stable && stable['tag_name']
        end

        # Finds latest prerelease tag greater than given version.
        #
        # @param stable_major [Integer] major version floor
        # @param stable_minor [Integer] minor version floor
        # @param stable_patch [Integer] patch version floor
        # @return [String, nil] tag name (without 'v' prefix) or nil
        def latest_prerelease_tag_greater_than(stable_major, stable_minor, stable_patch = 0)
          releases = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
          return nil unless releases.is_a?(Array)

          prereleases = releases.select { |r| r['prerelease'] && r['tag_name'] }
          return nil if prereleases.empty?

          candidates = prereleases.select do |r|
            maj, min, patch = major_minor_patch_from(r['tag_name'])
            next false unless maj && min

            (maj > stable_major) ||
              (maj == stable_major && min > stable_minor) ||
              (maj == stable_major && min == stable_minor && patch > stable_patch)
          end
          return nil if candidates.empty?

          tag = candidates.max_by { |r| version_key(r['tag_name']) }['tag_name']
          tag.sub(/^v/, '')
        end

        # Finds latest branch matching prefix and greater than given version.
        #
        # @param prefix [String] branch name prefix (e.g. 'pre/beta')
        # @param stable_major [Integer] major version floor
        # @param stable_minor [Integer] minor version floor
        # @param stable_patch [Integer] patch version floor
        # @return [String, nil] branch name or nil
        def latest_prefixed_branch_greater_than(prefix, stable_major, stable_minor, stable_patch = 0)
          branches = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/branches?per_page=100")
          return nil unless branches.is_a?(Array)

          names = branches.map { |b| b['name'] }.compact
          candidates = names.select { |n| n.start_with?(prefix) }
          filtered = candidates.select do |n|
            maj, min, patch = major_minor_patch_from(n)
            maj && min && (
              (maj > stable_major) ||
              (maj == stable_major && min > stable_minor) ||
              (maj == stable_major && min == stable_minor && patch > stable_patch)
            )
          end
          return nil if filtered.empty?

          begin
            filtered.max_by { |n| version_key(n) }
          rescue => e
            respond "Update notice: ordering branches (latest_prefixed_branch_greater_than): #{e.message}"
            filtered.sort.last
          end
        end

        # Converts version string to comparable Gem::Version.
        #
        # @param tag_or_name [String] version string or tag name
        # @return [Gem::Version] comparable version object
        def version_key(tag_or_name)
          s = tag_or_name.to_s.sub(/^v/, '')
          if s =~ /(\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z\.]+)?)/
            s = Regexp.last_match(1)
          end
          s = s.gsub('-beta.', '.beta.').gsub(/-beta(?!\.)/, '.beta')
          Gem::Version.new(s)
        end

        # Extracts major, minor, patch version numbers from string.
        #
        # @param str [String, nil] version string
        # @return [Array<Integer, nil>] [major, minor, patch] or [nil, nil, nil]
        def major_minor_patch_from(str)
          return [nil, nil, nil] if str.nil?

          s = str.to_s.sub(/^v/, '')
          if s =~ /(\d+)\.(\d+)\.(\d+)/
            [$1.to_i, $2.to_i, $3.to_i]
          elsif s =~ /(\d+)\.(\d+)/
            [$1.to_i, $2.to_i, 0]
          else
            [nil, nil, nil]
          end
        end

        # Extracts major and minor version numbers from string.
        #
        # @param str [String, nil] version string
        # @return [Array<Integer, nil>] [major, minor]
        def major_minor_from(str)
          maj, min, _patch = major_minor_patch_from(str)
          [maj, min]
        end
      end
    end
  end
end
