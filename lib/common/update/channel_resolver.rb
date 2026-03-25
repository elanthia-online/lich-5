# frozen_string_literal: true

module Lich
  module Util
    module Update
      class ChannelResolver
        def initialize(client)
          @client = client
        end

        def resolve_channel_ref(channel)
          case channel
          when :stable, 'production'
            STABLE_REF
          when :beta
            stable_tag = latest_stable_tag
            stable_major, stable_minor, stable_patch = major_minor_patch_from(stable_tag)
            env = ENV['LICH_BETA_REF']
            return env unless env.nil? || env.empty?

            tag = latest_prerelease_tag_greater_than(stable_major, stable_minor, stable_patch)
            return tag if tag

            branch = latest_prefixed_branch_greater_than(BETA_BRANCH_PREFIX, stable_major, stable_minor, stable_patch)
            return branch if branch

            nil
          else
            STABLE_REF
          end
        end

        def latest_stable_tag
          releases = @client.fetch_github_json("https://api.github.com/repos/#{GITHUB_REPO}/releases")
          return nil unless releases.is_a?(Array)

          stable = releases.select { |r| !r['prerelease'] && r['tag_name'] }.max_by { |r| version_key(r['tag_name']) }
          stable && stable['tag_name']
        end

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

        def version_key(tag_or_name)
          s = tag_or_name.to_s.sub(/^v/, '')
          if s =~ /(\d+\.\d+(?:\.\d+)?(?:-[0-9A-Za-z\.]+)?)/
            s = Regexp.last_match(1)
          end
          s = s.gsub('-beta.', '.beta.').gsub(/-beta(?!\.)/, '.beta')
          Gem::Version.new(s)
        end

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

        def major_minor_from(str)
          maj, min, _patch = major_minor_patch_from(str)
          [maj, min]
        end
      end
    end
  end
end
