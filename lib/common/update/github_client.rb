# frozen_string_literal: true

=begin
  HTTP client for GitHub API with caching and token auth.

  Provides JSON and raw GET requests with optional Bearer token auth from
  DATA_DIR/githubtoken.txt. Includes in-memory cache with TTL for API responses.

  Failed requests do not print anything. The client records a classified
  FetchError in #last_error and writes the raw detail to the debug log; callers
  report the failure once, in terms of what was not done
  (see StatusReporter.respond_github_failure).
=end

module Lich
  module Util
    module Update
      # Classified reason the most recent GitHubClient request failed.
      #
      # kind is one of:
      #   :unavailable  - 5xx, 401, 408, or another unexpected status
      #   :rate_limited - 429, or a 403 carrying rate-limit signals; reset_at is set when GitHub reports it
      #   :not_found    - 404 (usually a misconfigured custom repo or branch)
      #   :rejected     - any other 4xx, e.g. 403 access denied or 409 empty repository
      #   :network      - connection, DNS, TLS, or timeout failure
      #   :bad_response - body could not be parsed or lacked the expected data
      FetchError = Struct.new(:kind, :status, :reset_at, keyword_init: true) do
        # GitHub-wide failures affect every repository, so a multi-repo sync
        # should stop instead of reporting the same outage once per repo.
        # 404 and other refusals are about one repository, so the sync carries on.
        #
        # @return [Boolean]
        def global?
          !%i[not_found rejected].include?(kind)
        end
      end

      class GitHubClient
        attr_reader :http_cache

        # @param cache_ttl [Integer] cache TTL in seconds (default: 60)
        def initialize(cache_ttl: 60)
          @http_cache = {}
          @cache_ttl = cache_ttl
          @github_token = nil
          @github_token_loaded = false
          @last_error_key = :"lich5_update_last_error_#{object_id}"
        end

        # Why the calling thread's most recent request failed, or nil if it
        # succeeded. Kept per thread: the client is shared, and the login sync
        # runs on its own thread while the user may run lich5-update.
        #
        # @return [FetchError, nil]
        def last_error
          Thread.current[@last_error_key]
        end

        # Fetches and parses JSON from GitHub API with caching.
        #
        # @param url [String] API URL
        # @return [Hash, Array, nil] parsed JSON or nil on error
        def fetch_github_json(url)
          now = Time.now.to_i
          entry = @http_cache[url]
          if entry && (now - entry[:ts] < @cache_ttl)
            self.last_error = nil
            return entry[:data]
          end
          begin
            raw = http_get(url)
            return nil unless raw

            data = JSON.parse(raw)
            @http_cache[url] = { ts: now, data: data }
            data
          rescue => e
            debug_log("could not parse response from #{url}: #{e.message}")
            self.last_error = FetchError.new(kind: :bad_response)
            nil
          end
        end

        # Performs HTTP GET request with optional token auth.
        #
        # Never prints. On failure, sets #last_error and returns nil. If GitHub
        # rejects the token (401), retries once anonymously: public repositories
        # do not need a token, so a stale githubtoken.txt should not block updates.
        #
        # @param url [String] target URL
        # @param auth [Boolean] whether to include token auth (default: true)
        # @return [String, nil] response body or nil on error
        def http_get(url, auth: true)
          self.last_error = nil
          uri = URI.parse(url)
          token = auth ? github_token : nil
          response = perform_get(uri, token)

          if response.code == '401' && token
            debug_log("HTTP 401 with token fetching #{uri.path}; retrying without token")
            response = perform_get(uri, nil)
            token_rejected if response.code == '200'
          end

          return response.body if response.code == '200'

          debug_log("HTTP #{response.code} fetching #{uri.path}")
          self.last_error = classify(response)
          nil
        rescue => e
          debug_log("network error fetching #{url}: #{e.class}: #{e.message}")
          self.last_error = FetchError.new(kind: :network)
          nil
        end

        # Loads GitHub token from DATA_DIR/githubtoken.txt (lazy, once).
        #
        # @return [String, nil] Bearer token header value or nil
        def github_token
          return @github_token if @github_token_loaded

          @github_token_loaded = true
          token_path = File.join(DATA_DIR, 'githubtoken.txt')
          return nil unless File.exist?(token_path)

          token = File.read(token_path).strip
          if token.empty?
            respond "[lich5-update: GitHub token file is empty. Using unauthenticated access.]"
            return nil
          end

          @github_token = "Bearer #{token}"
        end

        private

        # @param error [FetchError, nil]
        # @return [void]
        def last_error=(error)
          Thread.current[@last_error_key] = error
        end

        # @param uri [URI::Generic] target URI
        # @param token [String, nil] Authorization header value, or nil for anonymous
        # @return [Net::HTTPResponse]
        def perform_get(uri, token)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER

          request = Net::HTTP::Get.new(uri.request_uri)
          request['Authorization'] = token if token
          http.request(request)
        end

        # Maps a non-200 response to a FetchError.
        #
        # @param response [Net::HTTPResponse]
        # @return [FetchError]
        def classify(response)
          status = response.code.to_i
          if status == 429 || (status == 403 && rate_limited?(response))
            FetchError.new(kind: :rate_limited, status: status, reset_at: rate_limit_reset(response))
          elsif status == 404
            FetchError.new(kind: :not_found, status: status)
          elsif (400..499).cover?(status) && ![401, 408].include?(status)
            FetchError.new(kind: :rejected, status: status)
          else
            FetchError.new(kind: :unavailable, status: status)
          end
        end

        # GitHub's 403 means a rate limit only with one of these signals; a
        # secondary limit can arrive with neither header, only the message.
        #
        # @param response [Net::HTTPResponse]
        # @return [Boolean]
        def rate_limited?(response)
          response['x-ratelimit-remaining'] == '0' ||
            !response['retry-after'].to_s.empty? ||
            response.body.to_s.match?(/rate limit/i)
        end

        # Reads when a rate limit lifts, from x-ratelimit-reset (epoch seconds)
        # or retry-after (seconds from now).
        #
        # @param response [Net::HTTPResponse]
        # @return [Time, nil]
        def rate_limit_reset(response)
          if response['x-ratelimit-remaining'] == '0' && response['x-ratelimit-reset'].to_s =~ /\A\d+\z/
            Time.at(response['x-ratelimit-reset'].to_i)
          elsif response['retry-after'].to_s =~ /\A\d+\z/
            Time.now + response['retry-after'].to_i
          end
        end

        # Stops sending a token GitHub rejected and tells the user once per session.
        #
        # @return [void]
        def token_rejected
          @github_token = nil
          respond "[lich5-update: GitHub rejected the token in #{File.join(DATA_DIR, 'githubtoken.txt')}, so updates used anonymous access. If this keeps happening, replace or delete that file.]"
        end

        # @param msg [String]
        # @return [void]
        def debug_log(msg)
          Lich.log("lich5-update: #{msg}") if Lich.respond_to?(:log)
        end
      end
    end
  end
end
