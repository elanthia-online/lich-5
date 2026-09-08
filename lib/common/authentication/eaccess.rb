# frozen_string_literal: true

require "openssl"
require "socket"
require_relative "launch_result"

module Lich
  module Common
    module Authentication
      # Core EAccess protocol implementation for Simutronics game servers
      # Handles SSL socket creation, certificate management, and game authentication protocol
      module EAccess
        # Authentication error raised when EAccess authentication fails
        class AuthenticationError < StandardError
          attr_reader :error_code

          def initialize(error_code)
            @error_code = error_code
            super("Error(#{error_code})")
          end
        end

        PACKET_SIZE = 8192

        # Character code that enters the character generator instead of selecting an existing character.
        # When sent via the L command, the game server starts the character creation flow.
        NEW_CHARACTER_CODE = "0"

        # Bounds the TCP connect to eaccess.play.net:7910 so a silently-dropped
        # SYN (firewalled/blocked, no RST) fails in seconds instead of hanging
        # on the OS connect timeout (commonly ~75s on Linux, driven by
        # tcp_syn_retries) -- observed live when the port is unreachable but
        # not actively refused. This only bounds the TCP handshake itself; it
        # is not a substitute for auth_with_timeout's overall watchdog, which
        # also covers the TLS handshake and the K/A/M/F/G/P/C/L exchange.
        CONNECT_TIMEOUT = 5

        # Simutronics-recognized rejection tokens the `A` command can return.
        # Distinguishes a normal, expected credential rejection from an
        # unrecognized/empty/malformed response, which points at a different
        # class of problem (relay or backend divergence) -- see
        # docs/eaccess-failure-diagnostics.md.
        KNOWN_REJECTION_TOKENS = %w[REJECT NORECORD INVALID PASSWORD].freeze

        # @param error [StandardError] the error raised by the a_response stage
        # @return [String] a probable-cause hint distinguishing a normal credential
        #   rejection from an unrecognized response
        # @api private
        def self.classify_a_response_failure(error)
          code = error.respond_to?(:error_code) ? error.error_code : nil
          if code && KNOWN_REJECTION_TOKENS.any? { |token| code.include?(token) }
            "recognized credential rejection (#{code}) -- normal, not a backend issue"
          else
            "unrecognized/malformed response -- possible application/backend divergence"
          end
        end

        # Wraps a step of the connect/handshake/protocol exchange so a
        # failure is logged with which stage it happened in, how long that
        # stage ran before failing, and a probable-cause hint -- see
        # docs/eaccess-failure-diagnostics.md for the full taxonomy. Never
        # logs raw protocol response bodies, the account password, or the
        # session key: only the stage name, exception class/message, and the
        # derived probable-cause classification.
        #
        # Also records the stage name on the current thread so
        # auth_with_timeout can report which stage was in flight if the
        # overall watchdog has to kill a hung attempt.
        #
        # @param name [String] stage identifier (see docs/eaccess-failure-diagnostics.md)
        # @param probable_cause [String, Proc] a fixed hint, or a callable receiving the raised
        #   error and returning a hint -- used when the classification depends on what failed
        #   (e.g. a_response's recognized-rejection-vs-divergence split)
        # @yield the stage's work
        # @return the block's return value
        # @raise [StandardError] re-raises whatever the block raised, after logging
        # @api private
        def self.stage(name, probable_cause:)
          Thread.current[:eaccess_stage] = name
          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          yield
        rescue StandardError => e
          duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
          cause = probable_cause.respond_to?(:call) ? probable_cause.call(e) : probable_cause
          Lich.log "warn: EAccess stage '#{name}' failed after #{duration}s (#{e.class}: #{e.message}) -- likely cause: #{cause}"
          raise
        end

        # @api private
        def self.pem
          @pem ||= File.join(DATA_DIR, "simu.pem")
        end

        # @api private
        def self.pem_exist?
          File.exist? pem
        end

        # @api private
        def self.download_pem(hostname = "eaccess.play.net", port = 7910)
          # Create an OpenSSL context
          ctx = OpenSSL::SSL::SSLContext.new
          # Get remote TCP socket, bounded so an unreachable port fails fast
          # instead of hanging on the OS connect timeout -- see CONNECT_TIMEOUT.
          sock = stage("tcp_connect:pem_bootstrap", probable_cause: "firewall/routing/load-balancer silently dropping packets (probable), or the host actively refusing (distinct cause)") do
            Socket.tcp(hostname, port, connect_timeout: CONNECT_TIMEOUT)
          end
          # pass that socket to OpenSSL
          ssl = OpenSSL::SSL::SSLSocket.new(sock, ctx)
          # establish connection, if possible
          stage("tls_handshake:pem_bootstrap", probable_cause: "TLS termination misconfiguration (not probable on its own)") do
            ssl.connect
          rescue StandardError
            # sync_close only closes the underlying TCP socket when the
            # SSLSocket itself is explicitly closed -- a failed connect never
            # reaches that point, and would otherwise leak this descriptor.
            sock.close rescue nil
            raise
          end
          # write the .pem to disk
          File.write(pem, ssl.peer_cert)
        end

        # @api private
        def self.verify_pem(conn)
          # return if conn.peer_cert.to_s = File.read(pem)
          if !(conn.peer_cert.to_s == File.read(pem))
            # Ambiguous by design: a legitimate Simutronics cert rotation and
            # a MITM presenting a different certificate look identical here.
            # Flagged as its own stage (cert_pin_mismatch) rather than folded
            # into a generic warning -- see docs/eaccess-failure-diagnostics.md.
            # The certificate itself is public data, not a secret, so it's
            # safe to log in full for diagnosis.
            Lich.log "warn: EAccess stage 'cert_pin_mismatch' -- peer certificate differs from the " \
                     "pinned #{pem}; re-pinning automatically. Expected on a legitimate cert " \
                     "rotation, but indistinguishable here from a MITM presenting a different " \
                     "certificate. was:\n#{conn.peer_cert}"
            download_pem
          else
            return true
          end
        end

        # @api private
        def self.socket(hostname = "eaccess.play.net", port = 7910)
          download_pem unless pem_exist?
          # Bounded connect -- see CONNECT_TIMEOUT.
          socket = stage("tcp_connect:main", probable_cause: "firewall/routing/load-balancer silently dropping packets (probable), or the host actively refusing (distinct cause)") do
            Socket.tcp(hostname, port, connect_timeout: CONNECT_TIMEOUT)
          end
          cert_store              = OpenSSL::X509::Store.new
          ssl_context             = OpenSSL::SSL::SSLContext.new
          ssl_context.cert_store  = cert_store
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          cert_store.add_file(pem) if pem_exist?
          ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
          ssl_socket.sync_close = true
          connected = stage("tls_handshake:main", probable_cause: "TLS termination misconfiguration (not probable on its own)") do
            ssl_socket.connect
          rescue StandardError
            # sync_close only closes the underlying TCP socket when the
            # SSLSocket itself is explicitly closed -- a failed connect never
            # reaches that point, and would otherwise leak this descriptor
            # across retries/fallback.
            socket.close rescue nil
            raise
          end
          # Not wrapped in the tls_handshake stage above: a cert mismatch is
          # its own distinct stage (cert_pin_mismatch, logged inside
          # verify_pem), not a handshake failure -- the handshake itself
          # already succeeded by this point.
          EAccess.verify_pem(connected)
          return ssl_socket
        end

        # Authenticates with the EAccess server and launches a character session.
        #
        # When +generator+ is true, the character lookup is skipped and the server
        # enters the character generator (character code "0") instead of selecting
        # an existing character.
        #
        # @param password [String] account password (plaintext, will be hashed)
        # @param account [String] account name
        # @param character [String, nil] character name to select
        # @param game_code [String, nil] game instance code (e.g. "DR", "GS3")
        # @param legacy [Boolean] use legacy multi-game enumeration flow
        # @param generator [Boolean] enter the character generator instead of selecting a character
        # @return [Hash, Array] login info hash (normal) or array of character hashes (legacy)
        # @raise [AuthenticationError] on auth failure or character not found
        def self.auth(password:, account:, character: nil, game_code: nil, legacy: false, generator: false)
          # Set Account module state
          if defined?(Lich::Common::Account)
            Lich::Common::Account.name = account
            Lich::Common::Account.game_code = game_code
            Lich::Common::Account.character = character
          end

          conn = EAccess.socket()
          begin
            # it is vitally important to verify self-signed certs
            # because there is no chain-of-trust for them
            EAccess.verify_pem(conn)

            hashkey = stage("k_response", probable_cause: "a relay or the EAccess target behind 7910 (possible)") do
              conn.puts "K\n"
              key = EAccess.read(conn)
              # A malformed/empty K response would otherwise silently produce
              # garbage password bytes below, surfacing two steps later as an
              # unrelated-looking a_response failure instead of being
              # attributed to this stage.
              raise AuthenticationError, "MALFORMED_K_RESPONSE" if key.to_s.strip.empty?

              key
            end
            # pp "hash=%s" % hashkey
            password = password.split('').map { |c| c.getbyte(0) }
            hashkey = hashkey.split('').map { |c| c.getbyte(0) }
            password.each_index { |i| password[i] = ((password[i] - 32) ^ hashkey[i]) + 32 }
            password = password.map { |c| c.chr }.join

            stage("a_response", probable_cause: ->(e) { classify_a_response_failure(e) }) do
              conn.puts "A\t#{account}\t#{password}\n"
              response = EAccess.read(conn)
              unless /KEY\t(?<key>.*)\t/.match(response)
                error_code = response.split(/\s+/).last
                raise AuthenticationError, error_code
              end
            end
            # pp "A:response=%s" % response
            response = stage("m_response", probable_cause: "session accepted but the immediate follow-up command failed -- possible session-affinity issue on a load-balanced backend") do
              conn.puts "M\n"
              m_response = EAccess.read(conn)
              raise StandardError, m_response unless m_response =~ /^M\t/

              m_response
            end
            # pp "M:response=%s" % response

            unless legacy
              stage("entitlement_response", probable_cause: "a backend/DB dependency specific to entitlements, not the auth path itself") do
                conn.puts "F\t#{game_code}\n"
                response = EAccess.read(conn)
                # F reports the account's tier for this instance. NEW_TO_GAME is the
                # normal response for any instance the account is not subscribed to --
                # not an error. The generator path tolerates it because character
                # creation is exactly the flow that targets instances the account does
                # not already hold; whether creation is permitted is decided later by
                # the L response, not here.
                unless response =~ /NORMAL|PREMIUM|TRIAL|INTERNAL|FREE/ || (generator && response =~ /NEW_TO_GAME/)
                  raise StandardError, response
                end
                if defined?(Lich::Common::Account)
                  Lich::Common::Account.subscription = response
                end
                # pp "F:response=%s" % response
                conn.puts "G\t#{game_code}\n"
                EAccess.read(conn)
                # pp "G:response=%s" % response
                conn.puts "P\t#{game_code}\n"
                EAccess.read(conn)
                # pp "P:response=%s" % response
                conn.puts "C\n"
                response = EAccess.read(conn)
                # pp "C:response=%s" % response
                if defined?(Lich::Common::Account)
                  Lich::Common::Account.members = response
                end
              end

              char_code = generator ? NEW_CHARACTER_CODE : resolve_char_code(response, character)

              login_info = stage("l_response", probable_cause: "protocol/backend divergence at the final step") do
                conn.puts "L\t#{char_code}\tSTORM\n"
                l_response = EAccess.read(conn)
                # Both success and failure are prefixed with "L\t" (e.g. the server
                # returns "L\tPROBLEM\t1" when the account is not entitled to create on
                # this instance), so require the explicit OK before parsing the launch
                # payload -- otherwise a PROBLEM line is parsed into a garbage hash.
                unless l_response =~ /^L\tOK\t/
                  # On the generator path a PROBLEM here means the account has no
                  # entitlement to create a character on this instance (e.g. an
                  # unsubscribed Fallen/Shattered). Fail fast with a clear code rather
                  # than crash or launch broken data.
                  raise AuthenticationError, "GENERATOR_NOT_AVAILABLE" if generator
                  raise StandardError, l_response
                end
                # pp "L:response=%s" % l_response
                parsed = l_response.sub(/^L\tOK\t/, '')
                                   .split("\t")
                                   .map { |kv|
                                     k, v = kv.split("=")
                                     [k.downcase, v]
                                   }.to_h
                LaunchResult.normalize(parsed)
              end
            else
              login_info = Array.new
              for game in response.sub(/^M\t/, '').scan(/[^\t]+\t[^\t\n]+/)
                game_code, game_name = game.split("\t")
                # pp "M:response = %s" % response
                conn.puts "N\t#{game_code}\n"
                response = EAccess.read(conn)
                if response =~ /STORM/
                  conn.puts "F\t#{game_code}\n"
                  response = EAccess.read(conn)
                  if response =~ /NORMAL|PREMIUM|TRIAL|INTERNAL|FREE/
                    if defined?(Lich::Common::Account)
                      Lich::Common::Account.subscription = response
                    end
                    conn.puts "G\t#{game_code}\n"
                    EAccess.read(conn)
                    conn.puts "P\t#{game_code}\n"
                    EAccess.read(conn)
                    conn.puts "C\n"
                    response = EAccess.read(conn)
                    if defined?(Lich::Common::Account)
                      Lich::Common::Account.members = response
                    end
                    for code_name in response.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '').scan(/[^\t]+\t[^\t\n]+/)
                      char_code, char_name = code_name.split("\t")
                      hash = { :game_code => "#{game_code}", :game_name => "#{game_name}",
                              :char_code => "#{char_code}", :char_name => "#{char_name}" }
                      login_info.push(hash)
                    end
                  end
                end
              end
            end
            return login_info
          ensure
            conn&.close unless conn&.closed?
          end
        end

        # Resolves the character code for the requested character from the C response.
        #
        # @param c_response [String] raw C command response from the server
        # @param character [String] character name to look up
        # @return [String] character code for the L command
        # @raise [AuthenticationError] when the character is not found in the response
        # @api private
        def self.resolve_char_code(c_response, character)
          char_entry = c_response.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '')
                                 .scan(/[^\t]+\t[^\t\n]+/)
                                 .find { |c| c.split("\t")[1] == character }

          raise AuthenticationError, "CHARACTER_NOT_FOUND" unless char_entry

          char_entry.split("\t")[0]
        end

        # @api private
        def self.read(conn)
          conn.sysread(PACKET_SIZE)
        end

        # Bounds how long the full SGE authentication exchange may block.
        #
        # {.auth} has no connect or read timeouts of its own -- every step (TCP
        # connect, TLS handshake, and each K/A/M/F/G/P/C/L round-trip) is a bare
        # blocking call. An unresponsive SGE backend (e.g. a stalled connect that
        # never gets a SYN-ACK) hangs the caller indefinitely with no exception
        # and no log output. This wraps the whole exchange the same way
        # {Lich::GameBase::Game.open_with_timeout} bounds the game connect.
        #
        # @param timeout [Integer, Float] seconds to wait for the full exchange
        # @param kwargs [Hash] forwarded to {.auth}
        # @return [Hash, Array] see {.auth}
        # @raise [RuntimeError] if the exchange does not complete within +timeout+
        # @raise [StandardError] re-raises whatever {.auth} raises
        # @see .auth
        def self.auth_with_timeout(timeout: 30, **kwargs)
          auth_thread = Thread.new {
            # report_on_exception off: a failed auth is surfaced by the join below
            # (which re-raises it), not by an auto-printed thread warning.
            Thread.current.report_on_exception = false
            auth(**kwargs)
          }
          if auth_thread.join(timeout).nil?
            # The stage marker set by `stage` lives on the thread object
            # itself, readable from here even after kill -- the one case
            # where the exchange hangs with no exception at all (a stalled
            # connect or a read that never returns) otherwise leaves zero
            # indication of which step it was stuck in. See
            # docs/eaccess-failure-diagnostics.md.
            stalled_stage = auth_thread[:eaccess_stage] || "connect (pre-stage)"
            auth_thread.kill rescue nil
            Lich.log "warn: EAccess timed out after #{timeout}s while in stage '#{stalled_stage}'"
            raise "error: timed out authenticating with EAccess after #{timeout}s"
          end
          auth_thread.value
        end
      end
    end
  end
end
