# frozen_string_literal: true

require "openssl"
require "socket"

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

        # SGE authentication endpoints. Simutronics exposes the same protocol on
        # a TLS listener (7910) and a legacy cleartext listener (7900). The K/A
        # password hash is applied identically on both, so the cleartext path
        # never transmits the raw password -- it only forgoes transport
        # encryption of an already-obscured exchange. We prefer TLS and fall back
        # to cleartext when the TLS port is unreachable (e.g. 7910 firewalled or
        # its SYNs dropped while 7900 stays open, as after the SGE move to AWS).
        HOST = "eaccess.play.net"
        TLS_PORT = 7910
        CLEARTEXT_PORT = 7900

        # Bounds the TCP connect to the TLS endpoint so a silently-dropped SYN on
        # 7910 fails over to cleartext in seconds instead of hanging on the OS
        # connect timeout (~75s).
        TLS_CONNECT_TIMEOUT = 5

        # Failures to *establish* the TLS connection that warrant a cleartext
        # retry. OpenSSL::SSL::SSLError is deliberately excluded: a
        # reachable-but-untrusted 7910 is a security signal we refuse on, not one
        # we silently downgrade around.
        CONNECT_ERRORS = [SocketError, SystemCallError]
        CONNECT_ERRORS << IO::TimeoutError if defined?(IO::TimeoutError)
        CONNECT_ERRORS.freeze

        # @api private
        def self.pem
          @pem ||= File.join(DATA_DIR, "simu.pem")
        end

        # @api private
        def self.pem_exist?
          File.exist? pem
        end

        # @api private
        def self.download_pem(hostname = HOST, port = TLS_PORT)
          # Create an OpenSSL context
          ctx = OpenSSL::SSL::SSLContext.new
          # Get remote TCP socket with a bounded connect so an unreachable TLS
          # port fails fast instead of hanging on the OS connect timeout.
          sock = Socket.tcp(hostname, port, connect_timeout: TLS_CONNECT_TIMEOUT)
          # pass that socket to OpenSSL
          ssl = OpenSSL::SSL::SSLSocket.new(sock, ctx)
          # establish connection, if possible
          ssl.connect
          # write the .pem to disk
          File.write(pem, ssl.peer_cert)
        end

        # @api private
        def self.verify_pem(conn)
          # return if conn.peer_cert.to_s = File.read(pem)
          if !(conn.peer_cert.to_s == File.read(pem))
            Lich.log "Exception, \nssl peer certificate did not match #{pem}\nwas:\n#{conn.peer_cert}"
            download_pem
          else
            return true
          end
          #     fail Exception, "\nssl peer certificate did not match #{pem}\nwas:\n#{conn.peer_cert}"
        end

        # Opens an SGE connection, preferring the verified TLS endpoint (7910)
        # and falling back to the legacy cleartext endpoint (7900) when the TLS
        # port cannot be reached.
        #
        # The TLS TCP connect is bounded by {TLS_CONNECT_TIMEOUT}: if 7910 is
        # firewalled or its SYNs are dropped (as happened after the SGE move to
        # AWS, where 7910 times out while 7900 still answers) the connect fails
        # fast and we retry on cleartext rather than hanging on the ~75s OS
        # connect timeout. Only connection-establishment failures ({CONNECT_ERRORS})
        # trigger the fallback -- a TLS/cert failure, or a later authentication
        # failure, is surfaced rather than silently downgraded.
        #
        # @return [OpenSSL::SSL::SSLSocket, Socket] the open connection
        # @api private
        def self.socket
          secure_socket
        rescue *CONNECT_ERRORS => e
          Lich.log "warning: EAccess TLS connect to #{HOST}:#{TLS_PORT} failed (#{e.class}: #{e.message}); falling back to cleartext #{HOST}:#{CLEARTEXT_PORT}"
          cleartext_socket
        end

        # Opens the verified TLS connection to the SGE endpoint.
        # @api private
        def self.secure_socket(hostname = HOST, port = TLS_PORT)
          download_pem unless pem_exist?
          tcp_socket              = Socket.tcp(hostname, port, connect_timeout: TLS_CONNECT_TIMEOUT)
          cert_store              = OpenSSL::X509::Store.new
          ssl_context             = OpenSSL::SSL::SSLContext.new
          ssl_context.cert_store  = cert_store
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          cert_store.add_file(pem) if pem_exist?
          ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, ssl_context)
          ssl_socket.sync_close = true
          EAccess.verify_pem(ssl_socket.connect)
          return ssl_socket
        end

        # Opens the legacy cleartext connection to the SGE endpoint.
        # @api private
        def self.cleartext_socket(hostname = HOST, port = CLEARTEXT_PORT)
          Socket.tcp(hostname, port, connect_timeout: TLS_CONNECT_TIMEOUT)
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
            # It is vitally important to verify self-signed certs because there
            # is no chain-of-trust for them. socket() already verified the peer on
            # the TLS path; the cleartext fallback is a plain Socket with no peer
            # cert, so guard the re-verify to the TLS socket.
            EAccess.verify_pem(conn) if conn.is_a?(OpenSSL::SSL::SSLSocket)
            conn.puts "K\n"
            hashkey = EAccess.read(conn)
            # pp "hash=%s" % hashkey
            password = password.split('').map { |c| c.getbyte(0) }
            hashkey = hashkey.split('').map { |c| c.getbyte(0) }
            password.each_index { |i| password[i] = ((password[i] - 32) ^ hashkey[i]) + 32 }
            password = password.map { |c| c.chr }.join
            conn.puts "A\t#{account}\t#{password}\n"
            response = EAccess.read(conn)
            unless /KEY\t(?<key>.*)\t/.match(response)
              error_code = response.split(/\s+/).last
              raise AuthenticationError, error_code
            end
            # pp "A:response=%s" % response
            conn.puts "M\n"
            response = EAccess.read(conn)
            raise StandardError, response unless response =~ /^M\t/
            # pp "M:response=%s" % response

            unless legacy
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
              char_code = generator ? NEW_CHARACTER_CODE : resolve_char_code(response, character)
              conn.puts "L\t#{char_code}\tSTORM\n"
              response = EAccess.read(conn)
              # Both success and failure are prefixed with "L\t" (e.g. the server
              # returns "L\tPROBLEM\t1" when the account is not entitled to create on
              # this instance), so require the explicit OK before parsing the launch
              # payload -- otherwise a PROBLEM line is parsed into a garbage hash.
              unless response =~ /^L\tOK\t/
                # On the generator path a PROBLEM here means the account has no
                # entitlement to create a character on this instance (e.g. an
                # unsubscribed Fallen/Shattered). Fail fast with a clear code rather
                # than crash or launch broken data.
                raise AuthenticationError, "GENERATOR_NOT_AVAILABLE" if generator
                raise StandardError, response
              end
              # pp "L:response=%s" % response
              login_info = response.sub(/^L\tOK\t/, '')
                                   .split("\t")
                                   .map { |kv|
                                     k, v = kv.split("=")
                                     [k.downcase, v]
                                   }.to_h
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
            auth_thread.kill rescue nil
            raise "error: timed out authenticating with EAccess after #{timeout}s"
          end
          auth_thread.value
        end
      end
    end
  end
end
