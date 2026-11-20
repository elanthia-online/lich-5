# frozen_string_literal: true

=begin
  Lich version floors for the updater.

  A script may declare the oldest Lich it runs on ("required: Lich >= X").
  The login sync and --script= never install a version whose floor the
  running Lich does not meet. When the newest version in a repository has an
  unmet floor, #newest_compatible walks that file's commit history, newest
  first, and returns the first version this Lich can run.

  The floor is read and compared by Lich::Common::Script, the same code a
  script uses to check itself when it starts.

  The history is every commit reachable from the branch that changed the
  file. On a branch that only takes squash merges, as the elanthia-online
  script repositories do, each of those is a version the branch itself held.
  A branch that takes merge commits also lists the intermediate commits of
  merged work, which were never published as a version, so callers search
  only the built-in repositories.
=end

module Lich
  module Util
    module Update
      class ScriptFloor
        # Most commits of one file examined for a version this Lich can run:
        # one page of the GitHub commits API at its default size. Each commit
        # examined costs one raw download, so this also bounds how long a
        # sync can spend on one script.
        MAX_HISTORY = 30

        # Outcome of #newest_compatible.
        #
        # status is one of:
        #   :found  - content and commit are the version to install
        #   :none   - none of the +examined+ versions runs on this Lich
        #   :failed - GitHub could not be read; error is the client's
        #             FetchError, or nil when the failure was not classified
        Result = Struct.new(:status, :content, :commit, :examined, :error, keyword_init: true)

        # A repository config's file-list URL, which names the repository
        # and the branch its scripts are read from.
        TREE_URL = %r{\Ahttps://api\.github\.com/repos/([^/]+/[^/]+)/git/trees/([^?]+)}
        private_constant :TREE_URL

        # Reads the floor from the script's bytes, the way a download
        # arrives. Text tagged as UTF-8 that holds other bytes (a Latin-1
        # comment, say) cannot be scanned as UTF-8 and would read as having
        # no floor.
        #
        # @param content [String] the full text of a script
        # @return [String, nil] the Lich version it declares as its floor
        def self.required_in(content)
          Lich::Common::Script.required_lich_version_in(content.b)
        end

        # @param required [String, nil] a floor from .required_in
        # @return [Boolean] whether the running Lich meets it; true for no floor
        def self.met?(required)
          Lich::Common::Script.lich_version_satisfied?(required)
        end

        # @param content [String] the full text of a script
        # @return [String, nil] the floor +content+ declares when the running
        #   Lich does not meet it; nil when it can run here
        def self.unmet(content)
          required = required_in(content)
          met?(required) ? nil : required
        end

        # Reads the repository and branch out of a repository config.
        #
        # @param config [Hash] repository config from SCRIPT_REPOS or a custom repo
        # @return [Hash{Symbol=>String}, nil] :repo ("owner/name") and :branch,
        #   or nil when the config's api_url is not a GitHub file-list URL
        def self.source_for(config)
          match = TREE_URL.match(config[:api_url].to_s)
          match && { repo: match[1], branch: match[2] }
        end

        # @param client [GitHubClient] GitHub API client instance
        def initialize(client)
          @client = client
        end

        # Finds the newest version of a file, among its last MAX_HISTORY
        # commits on a branch, whose floor the running Lich meets.
        #
        # One API request lists the commits; each version is then read from
        # raw.githubusercontent.com, which uses no API quota. The walk stops
        # at the first version that can run here. A commit at which the file
        # does not exist (it was removed and added back later) is passed
        # over. Any other failed read ends the walk as :failed, so a version
        # that could not be read is never mistaken for one that cannot run.
        #
        # @param source [Hash{Symbol=>String}, nil] :repo and :branch, as
        #   .source_for returns them
        # @param path [String] the file's path in the repository
        # @return [Result]
        def newest_compatible(source, path)
          return Result.new(status: :none, examined: 0) unless source

          commits = @client.fetch_github_json(commits_url(source, path))
          return Result.new(status: :failed, examined: 0, error: @client.last_error) unless commits.is_a?(Array)

          examined = 0
          commits.first(MAX_HISTORY).each do |commit|
            sha = commit.is_a?(Hash) ? commit['sha'].to_s : ''
            next unless sha.match?(/\A\h{7,64}\z/)

            content = @client.http_get("https://raw.githubusercontent.com/#{source[:repo]}/#{sha}/#{path}", auth: false)
            if content.nil?
              error = @client.last_error
              next if error&.kind == :not_found

              return Result.new(status: :failed, examined: examined, error: error)
            end

            examined += 1
            return Result.new(status: :found, content: content, commit: sha, examined: examined) if self.class.unmet(content).nil?
          end
          Result.new(status: :none, examined: examined)
        end

        private

        # @param source [Hash{Symbol=>String}] :repo and :branch
        # @param path [String] the file's path in the repository
        # @return [String] GitHub API URL listing the commits that changed
        #   +path+ on the branch, newest first
        # @api private
        def commits_url(source, path)
          query = URI.encode_www_form(sha: source[:branch], path: path, per_page: MAX_HISTORY)
          "https://api.github.com/repos/#{source[:repo]}/commits?#{query}"
        end
      end
    end
  end
end
