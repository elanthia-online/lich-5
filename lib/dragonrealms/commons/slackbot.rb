# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module Lich
  module DragonRealms
    # Slack API client for sending direct messages via DragonRealms LNet.
    #
    # Caches the Slack users list in a shared SQLite store (DB_Store) so all
    # characters on the same game instance share a single cached copy with
    # a 1-hour TTL. Randomized startup jitter prevents thundering herd on
    # simultaneous character logins.
    class SlackBot
      # Base error for all SlackBot failures.
      class Error < StandardError; end

      # Raised on network-level failures (timeouts, connection resets).
      class NetworkError < Error; end

      # Raised when the Slack API returns a non-ok response.
      class ApiError < Error; end

      # Raised on HTTP 429 responses from Slack.
      class ThrottlingError < ApiError
        # @return [Integer, nil] seconds to wait before retrying
        attr_reader :retry_after

        # @param msg [String] error message
        # @param retry_after [Integer, nil] seconds to wait before retrying
        def initialize(msg, retry_after = nil)
          super(msg)
          @retry_after = retry_after
        end
      end

      # @return [String, nil] human-readable error from the last failed operation
      attr_reader :error_message

      API_URL = 'https://slack.com/api/'
      LNET_SCRIPT_NAME = 'lnet'
      LICHBOTS = %w[Quilsilgas].freeze
      TOKEN_REQUEST_TIMEOUT = 10
      MAX_NETWORK_RETRIES = 5
      NO_USER_PATTERN = /\[server\]: "no user .*/.freeze

      LNET_CONNECTION_TIMEOUT = 30
      LNET_ACTIVITY_TIMEOUT = 120

      BASE_RETRY_DELAY_SECONDS = 30
      MAX_RETRY_DELAY_SECONDS = 300

      USERS_CACHE_SCRIPT = '_slackbot_users_cache'
      USERS_CACHE_TTL = 3600
      MAX_THROTTLE_RETRIES = 10

      def initialize
        @initialized = false
        @error_message = nil

        ensure_slack_token unless authed?(UserVars.slack_token)
        return if @error_message

        fetch_users_list
        @initialized = true
      end

      # @return [Boolean] true if the bot has a valid token and users list
      def initialized?
        @initialized
      end

      # Reinitializes the bot by re-fetching the token and users list.
      #
      # @return [Boolean] true if reconnection succeeded
      def reconnect!
        @error_message = nil
        @initialized = false

        ensure_slack_token unless authed?(UserVars.slack_token)
        return false if @error_message

        fetch_users_list
        @initialized = true
      end

      # Checks whether the LNet connection is alive and responsive.
      #
      # @return [Boolean]
      def lnet_connected?
        return false unless defined?(LNet)
        return false unless LNet.server
        return false if LNet.server.closed?

        if LNet.respond_to?(:last_recv) && LNet.last_recv
          return false if (Time.now - LNet.last_recv) > LNET_ACTIVITY_TIMEOUT
        end

        true
      rescue IOError, Errno::EBADF, Errno::EPIPE, NoMethodError
        false
      end

      # Tests whether a Slack API token is valid.
      #
      # @param token [String, nil] the token to test
      # @return [Boolean]
      def authed?(token)
        return false unless token

        post('auth.test', { 'token' => token })['ok']
      rescue ApiError, NetworkError
        false
      end

      # Sends a direct message to a Slack user.
      # Validates the username first, then reconnects if needed.
      #
      # @param username [String, nil] Slack username to message
      # @param message [String] message body
      # @return [Hash, nil] Slack API response, or nil on failure
      def direct_message(username, message)
        if username.nil? || username.to_s.strip.empty?
          Lich::Messaging.msg('bold', 'SlackBot: Cannot send message - no username provided. Check your slackbot_username setting.')
          return nil
        end

        reconnect! unless initialized?

        unless initialized?
          Lich::Messaging.msg('bold', 'SlackBot: Cannot send message - not connected. Will retry on next attempt.')
          return nil
        end

        dm_channel = get_dm_channel(username)
        unless dm_channel
          Lich::Messaging.msg('bold', "SlackBot: Cannot send message - user '#{username}' not found in Slack workspace.")
          return nil
        end

        params = {
          'token'   => UserVars.slack_token,
          'channel' => dm_channel,
          'text'    => "#{checkname}: #{message}",
          'as_user' => 'true'
        }
        post('chat.postMessage', params)
      rescue Error => e
        Lich.log "SlackBot: Failed to send Slack message to #{username}: #{e.message}"
        Lich::Messaging.msg('bold', "SlackBot: Failed to send Slack message to #{username}: #{e.message}")
      end

      private

      # @return [Boolean] true if the LNet script object is loaded
      def lnet_available?
        !@lnet.nil?
      end

      # Sets an error message and notifies the user in-game.
      #
      # @param message [String]
      # @return [void]
      def set_error(message)
        @error_message = message
        Lich::Messaging.msg('bold', "SlackBot: #{message}")
      end

      # Discovers and authenticates a Slack token via LNet.
      #
      # @return [void]
      def ensure_slack_token
        unless lnet_connected?
          unless Script.exists?(LNET_SCRIPT_NAME)
            set_error('lnet.lic not found - cannot retrieve Slack token')
            return
          end
          start_script(LNET_SCRIPT_NAME) unless Script.running?(LNET_SCRIPT_NAME)
          unless wait_for_lnet_connection
            set_error("lnet did not connect within #{LNET_CONNECTION_TIMEOUT} seconds.")
            return
          end
        end

        @lnet = (Script.running + Script.hidden).find { |val| val.name == LNET_SCRIPT_NAME }
        unless lnet_available?
          set_error('lnet script object not found.')
          return
        end

        return if find_token

        set_error('Unable to locate a Slack token')
      end

      # Blocks until LNet connects or timeout expires.
      #
      # @return [Boolean] true if connected within timeout
      def wait_for_lnet_connection
        start_time = Time.now
        until lnet_connected?
          return false if (Time.now - start_time) > LNET_CONNECTION_TIMEOUT

          pause 1
        end
        true
      end

      # Loads the users list from shared DB cache or Slack API.
      #
      # @return [void]
      def fetch_users_list
        cached = read_users_cache
        if cached
          @users_list = { 'members' => cached['members'] }
          Lich.log "SlackBot: Using cached users list (#{cached['members'].length} members)"
          return
        end

        sleep rand(0.0..5.0)

        cached = read_users_cache
        if cached
          @users_list = { 'members' => cached['members'] }
          Lich.log "SlackBot: Using cached users list after jitter (#{cached['members'].length} members)"
          return
        end

        @users_list = fetch_users_from_api
        write_users_cache(@users_list['members']) if @users_list['members']&.any?
      end

      # Fetches the users list from the Slack API with throttle retry.
      #
      # @return [Hash] response hash with 'members' key
      def fetch_users_from_api
        retries = 0
        begin
          post('users.list', { 'token' => UserVars.slack_token })
        rescue ThrottlingError => e
          cached = read_users_cache
          if cached
            Lich.log "SlackBot: Throttled, but another character cached the users list"
            return { 'members' => cached['members'] }
          end

          if retries >= MAX_THROTTLE_RETRIES
            Lich.log "SlackBot: Throttle retry limit (#{MAX_THROTTLE_RETRIES}) exceeded"
            Lich::Messaging.msg('bold', "SlackBot: Rate limit retry exhausted. User list unavailable.")
            return { 'members' => [] }
          end

          base_delay = e.retry_after || (BASE_RETRY_DELAY_SECONDS * (2**[retries, 3].min))
          delay = [base_delay, MAX_RETRY_DELAY_SECONDS].min
          jitter = rand(0..(delay * 0.5).to_i)
          total_delay = delay + jitter
          retries += 1
          Lich.log "SlackBot: Throttled fetching users list. Retry ##{retries} in #{total_delay}s..."
          Lich::Messaging.msg('bold', "SlackBot: Rate limited fetching users. Retrying in #{total_delay}s...") if retries <= 3
          sleep total_delay
          retry
        rescue ApiError, NetworkError => e
          Lich.log "SlackBot: Error fetching user list: #{e.message}"
          Lich::Messaging.msg('bold', "SlackBot: Failed to fetch Slack user list: #{e.message}")
          { 'members' => [] }
        end
      end

      # Reads cached users list from DB_Store.
      #
      # @return [Hash, nil] cached data with 'members' and 'fetched_at', or nil if missing/expired
      def read_users_cache
        data = Lich::Common::DB_Store.get_data(XMLData.game, USERS_CACHE_SCRIPT)
        return nil if data.nil? || data.empty?
        return nil unless data['fetched_at']
        return nil if (Time.now.to_i - data['fetched_at']) > USERS_CACHE_TTL

        data
      end

      # Writes users list to DB_Store cache with a timestamp.
      #
      # @param members [Array<Hash>] Slack user objects to cache
      # @return [void]
      def write_users_cache(members)
        Lich::Common::DB_Store.store_data(
          XMLData.game,
          USERS_CACHE_SCRIPT,
          { 'members' => members, 'fetched_at' => Time.now.to_i }
        )
        Lich.log "SlackBot: Cached #{members.length} Slack users for all characters"
      end

      # Searches LICHBOTS for a valid Slack token via LNet chat.
      #
      # @return [Boolean] true if a valid token was found and stored
      def find_token
        return false unless lnet_available?

        Lich::Messaging.msg('plain', 'SlackBot: Looking for a token...')

        LICHBOTS.any? do |bot|
          token = request_token(bot)
          authed = token && authed?(token)
          UserVars.slack_token = token if authed
          authed
        end
      end

      # Requests a Slack token from a LichBot via LNet private message.
      #
      # @param lichbot [String] name of the LichBot to request from
      # @return [String, false] token string, or false on failure/timeout
      def request_token(lichbot)
        return false unless lnet_available?

        send_time = Time.now
        @lnet.unique_buffer.push("chat to #{lichbot} RequestSlackToken")
        token_pattern = /\[Private\]-.*:#{Regexp.escape(lichbot)}: "slack_token: (?<token>.*)"/

        loop do
          line = get
          pause 0.05
          return false if Time.now - send_time > TOKEN_REQUEST_TIMEOUT

          if (match = line&.match(token_pattern))
            return match[:token] == 'Not Found' ? false : match[:token]
          end
          return false if line&.match?(NO_USER_PATTERN)
        end
      end

      # Posts to the Slack API with retry and exponential backoff on network errors.
      #
      # @param method [String] Slack API method name (e.g. 'chat.postMessage')
      # @param params [Hash] request parameters including token
      # @return [Hash] parsed JSON response body
      # @raise [ThrottlingError] on HTTP 429
      # @raise [NetworkError] after MAX_NETWORK_RETRIES exhausted
      # @raise [ApiError] on non-ok Slack responses or JSON parse errors
      def post(method, params)
        retries = 0

        begin
          uri = URI.parse("#{API_URL}#{method}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          req = Net::HTTP::Post.new(uri.path)
          req.set_form_data(params)

          res = http.request(req)

          if res.code == '429'
            retry_after = res['Retry-After']&.to_i
            raise ThrottlingError.new('Throttled by Slack API', retry_after)
          end

          raise NetworkError, "HTTP Error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

          body = JSON.parse(res.body)
          raise ApiError, "Slack API Error: #{body['error']}" unless body['ok']

          body
        rescue JSON::ParserError => e
          raise ApiError, "Failed to parse Slack API response: #{e.message}"
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, SocketError => e
          raise NetworkError, "SlackBot: Network error after #{MAX_NETWORK_RETRIES} retries: #{e.message}" if retries >= MAX_NETWORK_RETRIES

          delay = [BASE_RETRY_DELAY_SECONDS * (2**retries), MAX_RETRY_DELAY_SECONDS].min
          jitter = rand(0..(delay * 0.25).to_i)
          total_delay = delay + jitter
          retries += 1
          Lich.log "SlackBot: Network error: #{e.message}. Retry ##{retries} in #{total_delay}s..."
          sleep total_delay
          retry
        end
      end

      # Finds the DM channel ID for a Slack username.
      #
      # @param username [String] Slack username to look up
      # @return [String, nil] Slack user ID, or nil if not found
      def get_dm_channel(username)
        @users_list['members']&.find { |u| u['name'] == username }&.[]('id')
      end
    end
  end
end
