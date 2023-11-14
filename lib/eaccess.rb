require "openssl"
require "socket"
require 'lib/account.rb'

module EAccess
  PEM = File.join("#{DATA_DIR}/", "simu.pem")
  # pp PEM
  PACKET_SIZE = 8192

  def self.pem_exist?
    File.exist? PEM
  end

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
    File.write(EAccess::PEM, ssl.peer_cert)
  end

  def self.verify_pem(conn)
    # return if conn.peer_cert.to_s = File.read(EAccess::PEM)
    if !(conn.peer_cert.to_s == File.read(EAccess::PEM))
      Lich.log "Exception, \nssl peer certificate did not match #{EAccess::PEM}\nwas:\n#{conn.peer_cert}"
      download_pem
    else
      return true
    end
    #     fail Exception, "\nssl peer certificate did not match #{EAccess::PEM}\nwas:\n#{conn.peer_cert}"
  end

  def self.socket(hostname = "eaccess.play.net", port = 7910)
    download_pem unless pem_exist?
    socket = TCPSocket.open(hostname, port)
    cert_store              = OpenSSL::X509::Store.new
    ssl_context             = OpenSSL::SSL::SSLContext.new
    ssl_context.cert_store  = cert_store
    ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
    cert_store.add_file(EAccess::PEM) if pem_exist?
    ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
    ssl_socket.sync_close = true
    EAccess.verify_pem(ssl_socket.connect)
    return ssl_socket
  end

  def self.auth(password:, account:, character: nil, game_code: nil, legacy: false)
    Account.name = account
    Account.game_code = game_code
    conn = EAccess.socket()
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
      eaccess_error = "Error(%s)" % response.split(/\s+/).last
      return eaccess_error
    end
    # pp "A:response=%s" % response
    conn.puts "M\n"
    response = EAccess.read(conn)
    fail StandardError, response unless response =~ /^M\t/
    # pp "M:response=%s" % response

    unless legacy
      conn.puts "F\t#{game_code}\n"
      response = EAccess.read(conn)
      fail StandardError, response unless response =~ /NORMAL|PREMIUM|TRIAL|INTERNAL|FREE/
      Account.subscription = response
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
      Account.members = response
      char_code = response.sub(/^C\t[0-9]+\t[0-9]+\t[0-9]+\t[0-9]+[\t\n]/, '')
                          .scan(/[^\t]+\t[^\t^\n]+/)
                          .find { |c| c.split("\t")[1] == character }
                          .split("\t")[0]
      conn.puts "L\t#{char_code}\tSTORM\n"
      response = EAccess.read(conn)
      fail StandardError, response unless response =~ /^L\t/
      # pp "L:response=%s" % response
      conn.close unless conn.closed?
      login_info = Hash[response.sub(/^L\tOK\t/, '')
                                .split("\t")
                                .map { |kv|
                          k, v = kv.split("=")
                          [k.downcase, v]
                        }]
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
            Account.subscription = response
            conn.puts "G\t#{game_code}\n"
            EAccess.read(conn)
            conn.puts "P\t#{game_code}\n"
            EAccess.read(conn)
            conn.puts "C\n"
            response = EAccess.read(conn)
            Account.members = response
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
    conn.close unless conn.closed?
    return login_info
  end

  def self.read(conn)
    conn.sysread(PACKET_SIZE)
  end
end
