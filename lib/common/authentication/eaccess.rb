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
          # Get remote TCP socket
          sock = TCPSocket.new(hostname, port)
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

        # @api private
        def self.socket(hostname = "eaccess.play.net", port = 7910)
          download_pem unless pem_exist?
          socket = TCPSocket.open(hostname, port)
          cert_store              = OpenSSL::X509::Store.new
          ssl_context             = OpenSSL::SSL::SSLContext.new
          ssl_context.cert_store  = cert_store
          ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
          cert_store.add_file(pem) if pem_exist?
          ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
          ssl_socket.sync_close = true
          EAccess.verify_pem(ssl_socket.connect)
          return ssl_socket
        end

        def self.auth(password:, account:, character: nil, game_code: nil, legacy: false)
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
              raise StandardError, response unless response =~ /NORMAL|PREMIUM|TRIAL|INTERNAL|FREE/
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
              char_entry = response.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '')
                                   .scan(/[^\t]+\t[^\t^\n]+/)
                                   .find { |c| c.split("\t")[1] == character }
              unless char_entry
                raise AuthenticationError, "CHARACTER_NOT_FOUND"
              end
              char_code = char_entry.split("\t")[0]
              conn.puts "L\t#{char_code}\tSTORM\n"
              response = EAccess.read(conn)
              raise StandardError, response unless response =~ /^L\t/
              # pp "L:response=%s" % response
              login_info = response.sub(/^L\tOK\t/, '')
                                   .split("\t")
                                   .map { |kv|
                                     k, v = kv.split("=")
                                     [k.downcase, v]
                                   }.to_h
            else
              login_info = Array.new
              for game in response.sub(/^M\t/, '').scan(/[^\t]+\t[^\t^\n]+/)
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
                    for code_name in response.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '').scan(/[^\t]+\t[^\t^\n]+/)
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

        # @api private
        def self.read(conn)
          conn.sysread(PACKET_SIZE)
        end
      end
    end
  end
end
