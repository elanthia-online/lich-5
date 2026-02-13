# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module Lich
  module DragonRealms
    class SlackBot
      class Error < StandardError; end
      class NetworkError < Error; end
      class ApiError < Error; end

      class ThrottlingError < ApiError
        attr_reader :retry_after

        def initialize(msg, retry_after = nil)
          super(msg)
          @retry_after = retry_after
        end
      end

      attr_reader :error_message

      API_URL = 'https://slack.com/api/'
      LNET_SCRIPT_NAME = 'lnet'
      LICHBOTS = %w[Quilsilgas].freeze
      TOKEN_REQUEST_TIMEOUT = 10
      MAX_RETRIES = 5
      NO_USER_PATTERN = /\[server\]: "no user .*/.freeze

      LNET_CONNECTION_TIMEOUT = 30

      # Consider lnet connection stale if no activity for 2 minutes
      LNET_ACTIVITY_TIMEOUT = 120

      # Base delay for exponential backoff on API retries.
      # Slack recommends waiting at least 30 seconds before retrying after rate limits.
      # See: https://api.slack.com/docs/rate-limits
      BASE_RETRY_DELAY_SECONDS = 30

      # Maximum delay before giving up on retries (2 minutes)
      MAX_RETRY_DELAY_SECONDS = 120

      def initialize
        @initialized = false
        @error_message = nil

        ensure_slack_token unless authed?(UserVars.slack_token)
        return if @error_message

        fetch_users_list
        @initialized = true
      end

      def initialized?
        @initialized
      end

      def lnet_connected?
        return false unless defined?(LNet)
        return false unless LNet.server
        return false if LNet.server.closed?

        # Check last activity if method exists
        if LNet.respond_to?(:last_recv) && LNet.last_recv
          return false if (Time.now - LNet.last_recv) > LNET_ACTIVITY_TIMEOUT
        end

        true
      rescue IOError, Errno::EBADF, Errno::EPIPE, NoMethodError
        false
      end

      def authed?(token)
        return false unless token

        post('auth.test', { 'token' => token })['ok']
      rescue ApiError, NetworkError
        false
      end

      def direct_message(username, message)
        dm_channel = get_dm_channel(username)
        raise Error, "Could not find DM channel for #{username}" unless dm_channel

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

      def lnet_available?
        !@lnet.nil?
      end

      def set_error(message)
        @error_message = message
        Lich::Messaging.msg('bold', "SlackBot: #{message}")
      end

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

      def wait_for_lnet_connection
        start_time = Time.now
        until lnet_connected?
          return false if (Time.now - start_time) > LNET_CONNECTION_TIMEOUT

          pause 1
        end
        true
      end

      def fetch_users_list
        @users_list = post('users.list', { 'token' => UserVars.slack_token })
      rescue ApiError => e
        Lich.log "SlackBot: Error fetching user list: #{e.message}"
        Lich::Messaging.msg('bold', "SlackBot: Failed to fetch Slack user list: #{e.message}")
        @users_list = { 'members' => [] }
      end

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
        rescue ThrottlingError => e
          raise ApiError, "SlackBot: Throttled by Slack API. Max retries (#{MAX_RETRIES}) exceeded." if retries >= MAX_RETRIES

          delay = e.retry_after || (BASE_RETRY_DELAY_SECONDS * (2**retries))
          if delay > MAX_RETRY_DELAY_SECONDS
            raise ApiError, "SlackBot: Throttled by Slack API. Retry delay (#{delay}s) exceeds maximum."
          end

          Lich.log "SlackBot: Throttled by Slack API. Retrying in #{delay} seconds..."
          sleep delay
          retries += 1
          retry
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, SocketError => e
          raise NetworkError, "SlackBot: Network error. Max retries (#{MAX_RETRIES}) exceeded." if retries >= MAX_RETRIES

          delay = BASE_RETRY_DELAY_SECONDS * (2**retries)
          if delay > MAX_RETRY_DELAY_SECONDS
            raise NetworkError, "SlackBot: Network error. Retry delay (#{delay}s) exceeds maximum."
          end

          Lich.log "SlackBot: Network error: #{e.message}. Retrying in #{delay} seconds..."
          sleep delay
          retries += 1
          retry
        end
      end

      def get_dm_channel(username)
        @users_list['members']&.find { |u| u['name'] == username }&.[]('id')
      end
    end
  end
end
