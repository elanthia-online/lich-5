# frozen_string_literal: true

=begin
  HTTP client for GitHub API with caching and token auth.

  Provides JSON and raw GET requests with optional Bearer token auth from
  DATA_DIR/githubtoken.txt. Includes in-memory cache with TTL for API responses.
=end

module Lich
  module Util
    module Update
      class GitHubClient
        attr_reader :http_cache

        # @param cache_ttl [Integer] cache TTL in seconds (default: 60)
        def initialize(cache_ttl: 60)
          @http_cache = {}
          @cache_ttl = cache_ttl
          @github_token = nil
          @github_token_loaded = false
        end

        # Fetches and parses JSON from GitHub API with caching.
        #
        # @param url [String] API URL
        # @return [Hash, Array, nil] parsed JSON or nil on error
        def fetch_github_json(url)
          now = Time.now.to_i
          entry = @http_cache[url]
          if entry && (now - entry[:ts] < @cache_ttl)
            return entry[:data]
          end
          begin
            raw = http_get(url)
            return nil unless raw

            data = JSON.parse(raw)
            @http_cache[url] = { ts: now, data: data }
            data
          rescue => e
            respond "Update notice: network error fetching #{url.split('/repos/').last || url} (fetch_github_json): #{e.message}"
            nil
          end
        end

        # Performs HTTP GET request with optional token auth.
        #
        # @param url [String] target URL
        # @param auth [Boolean] whether to include token auth (default: true)
        # @return [String, nil] response body or nil on error
        def http_get(url, auth: true)
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER

          request = Net::HTTP::Get.new(uri.request_uri)
          if auth
            token = github_token
            request['Authorization'] = token if token
          end

          response = http.request(request)
          unless response.code == '200'
            respond "[lich5-update: HTTP #{response.code} fetching #{uri.path}]"
            return nil
          end
          response.body
        rescue => e
          respond "[lich5-update: Network error: #{e.message}]"
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
      end
    end
  end
end
