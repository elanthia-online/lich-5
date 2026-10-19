# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
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

      # Hard cap, in seconds, on each Slack API step (token check, users.list)
      # that #direct_message runs when it has to restore the connection. A
      # message is often sent right before an emergency logout, so it must
      # never wait out the full network or rate-limit backoff.
      SEND_REQUEST_BUDGET = 5

      # Part of a deadline request's remaining budget that net/http's own
      # connect timeouts share out. The rest is headroom before the hard
      # Timeout on the whole connect, so the two do not fire together.
      CONNECT_SHARE_OF_BUDGET = 0.9

      # After a failed users.list call, #direct_message makes no new call for
      # this many seconds (or for Slack's Retry-After, if longer, but never
      # more than MAX_RETRY_DELAY_SECONDS), so a burst of messages during an
      # outage neither waits on Slack nor hammers it.
      USERS_LIST_RETRY_COOLDOWN = 30

      USERS_LIST_UNAVAILABLE = 'Slack user list unavailable'

      def initialize
        @initialized = false
        @error_message = nil
        @token_verified = false
        @users_list = nil
        @users_list_retry_at = nil
        @restore_mutex = Mutex.new
        @restore_attempts = 0

        connect
      end

      # @return [Boolean] true if the bot has a valid token and a non-empty users list
      def initialized?
        @initialized
      end

      # Reinitializes the bot by re-checking the token and re-loading the users list.
      # A failed users-list load keeps any list loaded earlier.
      #
      # @param budget [Numeric, nil] seconds allowed for each Slack API step
      #   (token check, users.list), or nil for the full retry policy. The LNet
      #   token discovery keeps its own timeouts.
      # @return [Boolean] true if the token is valid and a non-empty users list
      #   (fresh, cached, or the one loaded earlier) is available
      def reconnect!(budget: nil)
        @error_message = nil
        @initialized = false
        @token_verified = false

        connect(budget: budget)
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
      # @param budget [Numeric, nil] seconds allowed for the check, or nil for
      #   the full retry policy
      # @return [Boolean]
      def authed?(token, budget: nil)
        return false unless token

        post('auth.test', { 'token' => token }, deadline: deadline_for(budget))['ok']
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

        restore_connection unless initialized?

        unless initialized?
          Lich::Messaging.msg('bold', 'SlackBot: Cannot send message - not connected. Will retry on next attempt.')
          return nil
        end

        dm_channel = get_dm_channel(username)
        dm_channel = get_dm_channel(username) if dm_channel.nil? && reload_users_cache(username)
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

      # Verifies (or discovers) the token, then loads the users list.
      # The bot is initialized only when a non-empty users list is loaded.
      #
      # @param budget [Numeric, nil] seconds allowed for each Slack API step
      # @return [Boolean] the new initialized? state
      def connect(budget: nil)
        ensure_slack_token(budget) unless authed?(UserVars.slack_token, budget: budget)
        return false if @error_message

        @token_verified = true
        load_users_list(budget)
      end

      # Loads the users list and updates initialized? and error_message.
      #
      # @param budget [Numeric, nil] seconds allowed, or nil for the full retry policy
      # @return [Boolean] the new initialized? state
      def load_users_list(budget)
        fetch_users_list(deadline_for(budget))
        @initialized = users_list_loaded?
        @error_message = @initialized ? nil : USERS_LIST_UNAVAILABLE
        @initialized
      end

      # Called by #direct_message when the bot is not initialized. If the token
      # was already verified and only the users list is missing, retries just
      # the users list (cache first, then one users.list try capped at
      # SEND_REQUEST_BUDGET; several calls if Slack's Retry-After fits in it)
      # without re-running the token discovery. Otherwise performs a full
      # #reconnect! whose token checks and users-list step are capped the same
      # way. The LNet token discovery keeps its own timeouts.
      #
      # Scripts share one bot from their own threads, so only one restore runs
      # at a time. A message that arrives while another message's restore is
      # running waits for it and takes its result instead of starting a second
      # one, so a burst of messages makes one users.list try (or one token
      # check and LNet discovery), and the later messages wait no longer than
      # the restore already under way.
      #
      # Never raises: a message is often sent right before an emergency logout,
      # and an unexpected error here must not stop the calling script.
      #
      # @return [Boolean] the new initialized? state
      def restore_connection
        attempts_seen = @restore_attempts
        @restore_mutex.synchronize do
          # Another message finished a restore while this one waited: share it.
          return initialized? if @restore_attempts != attempts_seen

          begin
            restore_connection_once
          ensure
            @restore_attempts += 1
          end
        end
      end

      # One restore attempt for #restore_connection. Never raises.
      #
      # @return [Boolean] the new initialized? state
      def restore_connection_once
        return load_users_list(SEND_REQUEST_BUDGET) if @token_verified

        reconnect!(budget: SEND_REQUEST_BUDGET)
      rescue StandardError => e
        Lich.log "SlackBot: Reconnect failed: #{e.class}: #{e.message}"
        @initialized = false
        @error_message = "Reconnect failed: #{e.message}"
        false
      end

      # @return [Boolean] true when a non-empty users list is loaded
      def users_list_loaded?
        members = @users_list && @users_list['members']
        members.is_a?(Array) && !members.empty?
      end

      # @return [Float] monotonic clock reading in seconds
      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # @param budget [Numeric, nil] seconds from now
      # @return [Float, nil] monotonic deadline, or nil when there is no budget
      def deadline_for(budget)
        budget && (monotonic_now + budget)
      end

      # @param deadline [Float] monotonic deadline
      # @return [Float] seconds left before the deadline (may be negative)
      def seconds_left(deadline)
        deadline - monotonic_now
      end

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
      # @param budget [Numeric, nil] seconds allowed for checking each token found
      # @return [void]
      def ensure_slack_token(budget = nil)
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

        return if find_token(budget)

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
      # On failure the current list (if any) is left untouched.
      #
      # @param deadline [Float, nil] monotonic deadline for the API attempt; when
      #   set, the startup jitter is skipped
      # @return [Boolean] true if a non-empty users list was loaded
      def fetch_users_list(deadline = nil)
        return true if load_users_from_cache('Using cached users list')

        unless deadline
          sleep rand(0.0..5.0)
          return true if load_users_from_cache('Using cached users list after jitter')
        end

        if deadline && users_list_cooling_down?
          Lich.log 'SlackBot: Skipping users.list until the retry cooldown ends'
          return false
        end

        members = fetch_users_from_api(deadline)
        return false unless members

        @users_list = { 'members' => members }
        true
      end

      # Replaces the users list with the shared cache when the cache is fresh
      # and non-empty. Makes no HTTP request.
      #
      # @param label [String] log message prefix
      # @return [Boolean] true if the cache was loaded
      def load_users_from_cache(label)
        members = cached_members
        return false unless members

        @users_list = { 'members' => members }
        Lich.log "SlackBot: #{label} (#{members.length} members)"
        true
      end

      # Called by #direct_message when an initialized bot does not know the
      # user: looks the user up in the shared cache in case another character
      # refreshed it, and adds that one entry to the current list. The list is
      # never replaced here, so a mistyped name or a cache written under
      # another token cannot drop users the bot already knows.
      # Never raises; a cache read error (e.g. a locked database) is logged and
      # the current list is kept, so the message still ends in "user not found"
      # rather than an exception in the calling script.
      #
      # @param username [String] the user the current list does not know
      # @return [Boolean] true if the cache listed the user
      def reload_users_cache(username)
        member = cached_members&.find { |u| u.is_a?(Hash) && u['name'] == username }
        return false unless member

        @users_list = { 'members' => @users_list['members'] + [member] }
        Lich.log "SlackBot: Added #{username} from the cached users list"
        true
      rescue StandardError => e
        Lich.log "SlackBot: Failed to reload cached users list: #{e.class}: #{e.message}"
        false
      end

      # @return [Boolean] true while a recent users.list failure blocks a new call from #direct_message
      def users_list_cooling_down?
        !@users_list_retry_at.nil? && monotonic_now < @users_list_retry_at
      end

      # Starts the cooldown after a failed users.list call. A longer wait
      # asked for by Slack is honoured up to MAX_RETRY_DELAY_SECONDS, so an
      # outsized Retry-After cannot block sends for hours.
      #
      # @param seconds [Numeric, nil] Slack's Retry-After, if any
      # @return [nil]
      def users_list_failed(seconds = nil)
        @users_list_retry_at = monotonic_now + seconds.to_i.clamp(USERS_LIST_RETRY_COOLDOWN, MAX_RETRY_DELAY_SECONDS)
        nil
      end

      # @return [Array<Hash>, nil] members from a fresh, non-empty shared cache
      def cached_members
        cached = read_users_cache
        members = cached && cached['members']
        members.is_a?(Array) && !members.empty? ? members : nil
      end

      # Fetches the users list from the Slack API with throttle retry, and
      # writes a successful result to the shared cache.
      #
      # @param deadline [Float, nil] monotonic deadline; retries that would
      #   overrun it are skipped
      # @return [Array<Hash>, nil] members, or nil on failure
      def fetch_users_from_api(deadline = nil)
        retries = 0
        begin
          members = post('users.list', { 'token' => UserVars.slack_token }, deadline: deadline)['members']
          unless members.is_a?(Array) && !members.empty?
            Lich.log 'SlackBot: users.list returned no members'
            Lich::Messaging.msg('bold', 'SlackBot: Failed to fetch Slack user list: Slack returned no members')
            return users_list_failed
          end

          @users_list_retry_at = nil
          write_users_cache(members)
          members
        rescue ThrottlingError => e
          members = cached_members
          if members
            Lich.log "SlackBot: Throttled, but another character cached the users list"
            return members
          end

          if retries >= MAX_THROTTLE_RETRIES
            Lich.log "SlackBot: Throttle retry limit (#{MAX_THROTTLE_RETRIES}) exceeded"
            Lich::Messaging.msg('bold', "SlackBot: Rate limit retry exhausted. User list unavailable.")
            return users_list_failed(e.retry_after)
          end

          # A Retry-After of 0 (or less) still waits 1 s, so the retries cannot run back to back.
          base_delay = e.retry_after ? [e.retry_after, 1].max : (BASE_RETRY_DELAY_SECONDS * (2**[retries, 3].min))
          delay = [base_delay, MAX_RETRY_DELAY_SECONDS].min
          jitter = rand(0..(delay * 0.5).to_i)
          total_delay = delay + jitter
          if deadline && total_delay >= seconds_left(deadline)
            Lich.log "SlackBot: Throttled fetching users list. Retry in #{total_delay}s would exceed the time budget"
            Lich::Messaging.msg('bold', 'SlackBot: Rate limited fetching users. Will retry on a later message.')
            return users_list_failed(e.retry_after)
          end

          retries += 1
          Lich.log "SlackBot: Throttled fetching users list. Retry ##{retries} in #{total_delay}s..."
          Lich::Messaging.msg('bold', "SlackBot: Rate limited fetching users. Retrying in #{total_delay}s...") if retries <= 3
          sleep total_delay
          retry
        rescue ApiError, NetworkError => e
          Lich.log "SlackBot: Error fetching user list: #{e.message}"
          Lich::Messaging.msg('bold', "SlackBot: Failed to fetch Slack user list: #{e.message}")
          users_list_failed
        rescue StandardError
          # An error post does not wrap (e.g. ECONNREFUSED) still counts as a
          # failed users.list call; the caller decides whether to rescue it.
          users_list_failed
          raise
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
      # @param budget [Numeric, nil] seconds allowed for checking each token found
      # @return [Boolean] true if a valid token was found and stored
      def find_token(budget = nil)
        return false unless lnet_available?

        Lich::Messaging.msg('plain', 'SlackBot: Looking for a token...')

        LICHBOTS.any? do |bot|
          token = request_token(bot)
          authed = token && authed?(token, budget: budget)
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
      # @param deadline [Float, nil] monotonic deadline; when set, each attempt
      #   is cut off at the deadline and retries that would overrun it are skipped
      # @return [Hash] parsed JSON response body
      # @raise [ThrottlingError] on HTTP 429
      # @raise [NetworkError] after MAX_NETWORK_RETRIES exhausted, or when the deadline is reached
      # @raise [ApiError] on non-ok Slack responses or JSON parse errors
      def post(method, params, deadline: nil)
        retries = 0

        begin
          uri = URI.parse("#{API_URL}#{method}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          req = Net::HTTP::Post.new(uri.path)
          req.set_form_data(params)

          res = deadline ? request_before(http, req, deadline) : http.request(req)

          if res.code == '429'
            # Retry-After is a whole number of seconds; anything else is ignored.
            retry_after = Integer(res['Retry-After'].to_s.strip, 10, exception: false)
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
          raise NetworkError, "SlackBot: Network error, no time left to retry: #{e.message}" if deadline && total_delay >= seconds_left(deadline)

          retries += 1
          Lich.log "SlackBot: Network error: #{e.message}. Retry ##{retries} in #{total_delay}s..."
          sleep total_delay
          retry
        end
      end

      # Performs one HTTP request that is abandoned at the deadline.
      #
      # Timeout's default interrupt is not a StandardError, so if it lands in
      # net/http's connect, net/http's `rescue => e` that closes the
      # half-open socket never runs and the socket leaks. Each step below
      # avoids that.
      #
      # With http_proxy set, net/http first resolves the target host to decide
      # whether to use the proxy. That lookup has no timeout of its own, so it
      # runs under the deadline before anything is opened, and the steps
      # below share what is left.
      #
      # Connecting has two steps, each bounded on its own by net/http: the TCP
      # connect and the TLS handshake (open_timeout). Through a proxy (taken
      # from http_proxy, which net/http always reaches without TLS) there is a
      # third, the CONNECT reply (read_timeout). Each step gets an equal share
      # of most of the remaining budget, so a step that hangs ends with
      # net/http's own error a little before the deadline. read_timeout only
      # bounds each read of the CONNECT reply, though, so a proxy that keeps
      # sending it a byte at a time could hold the connect without bound. The
      # whole connect therefore also runs under a Timeout that raises
      # Net::OpenTimeout, a StandardError, so net/http's connect still closes
      # its socket when it is interrupted. The headroom keeps net/http's own
      # timeouts from firing at the same moment as that interrupt.
      #
      # Once connected, the request runs under a Timeout for the rest of the
      # budget, and the connection is closed in an ensure outside both
      # Timeout blocks. The request is never sent after the deadline.
      #
      # @param http [Net::HTTP] a connection that is not started yet
      # @param req [Net::HTTP::Post]
      # @param deadline [Float] monotonic deadline
      # @return [Net::HTTPResponse]
      # @raise [NetworkError] if the deadline has passed before the request is sent
      # @raise [Timeout::Error] if the proxy lookup runs into the deadline,
      #   connecting times out (Net::OpenTimeout, or Net::ReadTimeout for a
      #   proxy's CONNECT reply) or the request is still running at the deadline
      def request_before(http, req, deadline)
        remaining = seconds_left(deadline)
        raise NetworkError, 'SlackBot: Time budget for the request is exhausted' if remaining <= 0

        # With http_proxy set, deciding whether to use it resolves the target
        # host, which has no timeout of its own. No socket is open yet, so
        # the interrupt cannot leak one. net/http keeps the answer for its
        # connect.
        proxied = Timeout.timeout(remaining) { http.proxy? }
        remaining = seconds_left(deadline)
        raise NetworkError, 'SlackBot: Time budget for the request is exhausted' if remaining <= 0

        # TCP connect and TLS handshake, plus the CONNECT reply through a proxy.
        share = remaining * CONNECT_SHARE_OF_BUDGET / (proxied ? 3.0 : 2.0)
        http.open_timeout = share
        http.read_timeout = share
        http.write_timeout = share
        begin
          Timeout.timeout(remaining, Net::OpenTimeout, 'SlackBot: connecting ran into the send deadline') { http.start }
          remaining = seconds_left(deadline)
          raise NetworkError, 'SlackBot: Time budget for the request ran out while connecting' if remaining <= 0

          http.read_timeout = remaining
          http.write_timeout = remaining
          Timeout.timeout(remaining) { http.request(req) }
        ensure
          # net/http's own cleanup for start with a block. Unlike finish, it
          # also closes a socket from a start interrupted after connecting
          # but before the session was marked started.
          http.send(:do_finish)
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
