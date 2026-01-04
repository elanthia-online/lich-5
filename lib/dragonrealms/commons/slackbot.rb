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

      def initialize
        @api_url = 'https://slack.com/api/'
        @initialized = false
        @error_message = nil

        unless authed?(UserVars.slack_token)
          unless Script.running?('lnet') && lnet_connected?
            unless Script.running?('lnet')
              unless Script.exists?('lnet')
                @error_message = "lnet.lic not found - cannot retrieve Slack token"
                return
              end
              start_script('lnet')
            end
            wait_time = 30
            start_time = Time.now
            until lnet_connected?
              if (Time.now - start_time) > wait_time
                @error_message = "lnet did not connect within #{wait_time} seconds."
                return
              end
              pause 1
            end
          end

          @lnet = (Script.running + Script.hidden).find { |val| val.name == 'lnet' }
          unless find_token
            @error_message = "Unable to locate a Slack token"
            return
          end
        end

        begin
          @users_list = post('users.list', { 'token' => UserVars.slack_token })
        rescue ApiError => e
          Lich.log "error fetching user list: #{e.message}"
          @users_list = { 'members' => [] }
        end

        @initialized = true
      end

      def initialized?
        @initialized
      end

      def lnet_connected?
        return false unless defined?(LNet)
        return false unless LNet.server
        return false if LNet.server.closed?

        begin
          # Check if socket is still viable
          ready = IO.select(nil, [LNet.server], nil, 0)
          return false unless ready

          # Check last activity if method exists
          if LNet.respond_to?(:last_recv) && LNet.last_recv
            return false if (Time.now - LNet.last_recv) > 120
          end

          true
        rescue IOError, Errno::EBADF, Errno::EPIPE, NoMethodError
          false
        end
      end

      def authed?(token)
        return false unless token
        begin
          post('auth.test', { 'token' => token })['ok']
        rescue ApiError, NetworkError
          false
        end
      end

      def request_token(lichbot)
        ttl = 10
        send_time = Time.now
        @lnet.unique_buffer.push("chat to #{lichbot} RequestSlackToken")
        loop do
          line = get
          pause 0.05
          return false if Time.now - send_time > ttl

          case line
          when /\[Private\]-.*:#{lichbot}: "slack_token: (.*)"/
            msg = Regexp.last_match(1)
            return msg != 'Not Found' ? msg : false
          when /\[server\]: "no user .*/
            return false
          end
        end
      end

      def find_token
        lichbots = %w[Quilsilgas]
        echo 'Looking for a token...'
        pause until @lnet

        lichbots.any? do |bot|
          token = request_token(bot)
          authed = authed?(token) if token
          UserVars.slack_token = token if token && authed
          authed
        end
      end

      def post(method, params)
        retries = 0
        base_delay = 30

        begin
          uri = URI.parse("#{@api_url}#{method}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Consider using VERIFY_PEER and configuring certs
          req = Net::HTTP::Post.new(uri.path)
          req.set_form_data(params)

          res = http.request(req)

          if res.code == '429'
            retry_after = res['Retry-After']&.to_i
            raise ThrottlingError.new("Throttled by Slack API", retry_after)
          end

          raise NetworkError, "HTTP Error: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

          body = JSON.parse(res.body)
          raise ApiError, "Slack API Error: #{body['error']}" unless body['ok']

          return body
        rescue JSON::ParserError => e
          raise ApiError, "Failed to parse Slack API response: #{e.message}"
        rescue ThrottlingError => e
          delay = e.retry_after || (base_delay * (2**retries))
          if delay > 120
            raise ApiError, "Throttled by Slack API. Retry delay (#{delay}s) exceeds maximum."
          end
          Lich.log "Throttled by Slack API. Retrying in #{delay} seconds..."
          sleep delay
          retries += 1
          retry
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError, SocketError => e
          delay = base_delay * (2**retries)
          if delay > 120
            raise NetworkError, "Network error. Retry delay (#{delay}s) exceeds maximum."
          end
          Lich.log "Network error: #{e.message}. Retrying in #{delay} seconds..."
          sleep delay
          retries += 1
          retry
        end
      end

      def direct_message(username, message)
        begin
          dm_channel = get_dm_channel(username)
          raise Error, "Could not find DM channel for #{username}" unless dm_channel

          params = { 'token' => UserVars.slack_token, 'channel' => dm_channel, 'text' => "#{checkname}: #{message}", 'as_user' => true }
          post('chat.postMessage', params)
        rescue Error => e
          Lich.log "Failed to send Slack message to #{username}: #{e.message}"
        end
      end

      def get_dm_channel(username)
        user = @users_list['members'].find { |u| u['name'] == username }
        user ? user['id'] : nil
      end
    end
  end
end
