# Carve out for later carving and refining - main_thread and reconnect
# this needs work to break up and improve 2024-06-13

reconnect_if_wanted = proc {
  if ARGV.include?('--reconnect') and ARGV.include?('--login') and not $_CLIENTBUFFER_.any? { |cmd| cmd =~ /^(?:\[.*?\])?(?:<c>)?(?:quit|exit)/i }
    if (reconnect_arg = ARGV.find { |arg| arg =~ /^\-\-reconnect\-delay=[0-9]+(?:\+[0-9]+)?$/ })
      reconnect_arg =~ /^\-\-reconnect\-delay=([0-9]+)(\+[0-9]+)?/
      reconnect_delay = $1.to_i
      reconnect_step = $2.to_i
    else
      reconnect_delay = 60
      reconnect_step = 0
    end
    Lich.log "info: waiting #{reconnect_delay} seconds to reconnect..."
    sleep reconnect_delay
    Lich.log 'info: reconnecting...'
    if (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      if $frontend == 'stormfront'
        system 'taskkill /FI "WINDOWTITLE eq [GSIV: ' + Char.name + '*"' # fixme: window title changing to Gemstone IV: Char.name # name optional
      end
      args = ['start rubyw.exe']
    else
      args = ['ruby']
    end
    args.push $PROGRAM_NAME.slice(/[^\\\/]+$/)
    args.concat ARGV
    args.push '--reconnected' unless args.include?('--reconnected')
    if reconnect_step > 0
      args.delete(reconnect_arg)
      args.concat ["--reconnect-delay=#{reconnect_delay + reconnect_step}+#{reconnect_step}"]
    end
    Lich.log "exec args.join(' '): exec #{args.join(' ')}"
    exec args.join(' ')
  end
}

@main_thread = Thread.new {
  test_mode = false
  $SEND_CHARACTER = '>'
  $cmd_prefix = '<c>'
  $clean_lich_char = $frontend == 'genie' ? ',' : ';'
  $lich_char = Regexp.escape($clean_lich_char)
  $lich_char_regex = Regexp.union(',', ';')

  @launch_data = nil
  require File.join(LIB_DIR, 'common', 'eaccess.rb')

  if ARGV.include?('--login')
    # CLI login flow: character authentication via saved entries
    require File.join(LIB_DIR, 'common', 'cli', 'cli_login')

    # Extract character name from --login argument
    requested_character = ARGV[ARGV.index('--login') + 1].capitalize

    # Parse game code and frontend from remaining arguments
    modifiers = ARGV.dup
    requested_instance, requested_fe = Lich::Util::LoginHelpers.resolve_login_args(modifiers)

    # Execute CLI login flow and get launch data
    launch_data_array = Lich::Common::CLI::CLILogin.execute(
      requested_character,
      game_code: requested_instance,
      frontend: requested_fe,
      data_dir: DATA_DIR
    )

    if launch_data_array
      Lich.log "info: CLI login successful for #{requested_character}"
      @launch_data = launch_data_array
    else
      $stdout.puts "error: failed to authenticate for #{requested_character}"
      Lich.log "error: CLI login failed for #{requested_character}"
      exit 1
    end

  ## GUI starts here

  elsif defined?(Gtk) and (ARGV.empty? or @argv_options[:gui])
    require File.join(LIB_DIR, 'common', 'gui-login.rb')
    gui_login
  end

  #
  # open the client and have it connect to us
  #

  $_SERVERBUFFER_ = LimitedArray.new
  $_SERVERBUFFER_.max_size = 400
  $_CLIENTBUFFER_ = LimitedArray.new
  $_CLIENTBUFFER_.max_size = 100

  Socket.do_not_reverse_lookup = true

  if @argv_options[:sal]
    begin
      @launch_data = File.open(@argv_options[:sal]) { |sal_file| sal_file.readlines }.collect { |line| line.chomp }
    rescue
      $stdout.puts "error: failed to read launch_file: #{$!}"
      Lich.log "info: launch_file: #{@argv_options[:sal]}"
      Lich.log "error: failed to read launch_file: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      exit
    end
  end

  if @launch_data
    if @launch_data.find { |opt| opt =~ /GAMECODE=DR/ }
      gamecodeshort = "DR"
      include Lich::DragonRealms
    else
      gamecodeshort = "GS"
      include Lich::Gemstone
    end
    unless (gamecode = @launch_data.find { |line| line =~ /GAMECODE=/ })
      $stdout.puts "error: launch_data contains no GAMECODE info"
      Lich.log "error: launch_data contains no GAMECODE info"
      exit(1)
    end
    unless (gameport = @launch_data.find { |line| line =~ /GAMEPORT=/ })
      $stdout.puts "error: launch_data contains no GAMEPORT info"
      Lich.log "error: launch_data contains no GAMEPORT info"
      exit(1)
    end
    unless (gamehost = @launch_data.find { |opt| opt =~ /GAMEHOST=/ })
      $stdout.puts "error: launch_data contains no GAMEHOST info"
      Lich.log "error: launch_data contains no GAMEHOST info"
      exit(1)
    end
    unless (game = @launch_data.find { |opt| opt =~ /GAME=/ })
      $stdout.puts "error: launch_data contains no GAME info"
      Lich.log "error: launch_data contains no GAME info"
      exit(1)
    end
    if (custom_launch = @launch_data.find { |opt| opt =~ /CUSTOMLAUNCH=/ })
      custom_launch.sub!(/^.*?\=/, '')
      Lich.log "info: using custom launch command: #{custom_launch}"
    elsif (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      Lich.log("info: Working against a Windows Platform for FE Executable")
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch = "Wizard.Exe /G#{gamecodeshort}/H127.0.0.1 /P%port% /K%key%"
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch = "Wrayth.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /Wrayth/
        custom_launch = "Stormfront.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /STORM/
      end
    elsif defined?(Wine)
      Lich.log("info: Working against a Linux | WINE Platform")
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch = "#{Wine::BIN} Wizard.Exe /G#{gamecodeshort}/H127.0.0.1 /P%port% /K%key%"
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch = "#{Wine::BIN} Wrayth.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /Wrayth/
        custom_launch = "#{Wine::BIN} Stormfront.exe /G#{gamecodeshort}/Hlocalhost/P%port%/K%key%" if $sf_fe_loc =~ /STORM/
      end
    end
    if (custom_launch_dir = @launch_data.find { |opt| opt =~ /CUSTOMLAUNCHDIR=/ })
      custom_launch_dir.sub!(/^.*?\=/, '')
      Lich.log "info: using working directory for custom launch command: #{custom_launch_dir}"
    elsif (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      Lich.log "info: Working against a Windows Platform for FE Location"
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch_dir = Lich.seek('wizard') # #HERE I AM
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch_dir = Lich.seek('stormfront') # #HERE I AM
      end
      Lich.log "info: Current Windows working directory is #{custom_launch_dir}"
    elsif defined?(Wine)
      Lich.log "Info: Working against a Linux | WINE Platform for FE location"
      if @launch_data.find { |opt| opt =~ /GAME=WIZ/ }
        custom_launch_dir_temp = Lich.seek('wizard') # #HERE I AM
        custom_launch_dir = custom_launch_dir_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
      elsif @launch_data.find { |opt| opt =~ /GAME=STORM/ }
        custom_launch_dir_temp = Lich.seek('stormfront') # #HERE I AM
        custom_launch_dir = custom_launch_dir_temp.gsub('\\', '/').gsub('C:', Wine::PREFIX + '/drive_c')
      end
      Lich.log "info: Current WINE working directory is #{custom_launch_dir}"
    end
    if ARGV.include?('--without-frontend')
      $frontend = 'unknown'
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    elsif game =~ /SUKS/i
      $frontend = 'suks'
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    elsif game =~ /AVALON/i
      # Simu strikes again
      launcher_cmd = "open -n -b Avalon \"%1\""
    elsif custom_launch
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    else
      unless (launcher_cmd = Lich.get_simu_launcher)
        $stdout.puts 'error: failed to find the Simutronics launcher'
        Lich.log 'error: failed to find the Simutronics launcher'
        exit(1)
      end
    end
    gamecode.split('=').last
    gameport = gameport.split('=').last
    gamehost = gamehost.split('=').last
    game     = game.split('=').last

    if (gameport == '10121') or (gameport == '10124')
      $platinum = true
    else
      $platinum = false
    end
    Lich.log "info: gamehost: #{gamehost}"
    Lich.log "info: gameport: #{gameport}"
    Lich.log "info: game: #{game}"
    if ARGV.include?('--without-frontend')
      $_CLIENT_ = nil
    elsif $frontend == 'suks'
      nil
    else
      if game =~ /WIZ/i
        $frontend = 'wizard'
      elsif game =~ /STORM/i
        $frontend = 'stormfront'
      elsif game =~ /AVALON/i
        $frontend = 'avalon'
      else
        $frontend = 'unknown'
      end
      begin
        listener = TCPServer.new('127.0.0.1', nil)
      rescue
        $stdout.puts "--- error: cannot bind listen socket to local port: #{$!}"
        Lich.log "error: cannot bind listen socket to local port: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        exit(1)
      end
      accept_thread = Thread.new { $_CLIENT_ = SynchronizedSocket.new(listener.accept) }
      localport = listener.addr[1]
      Frontend.create_session_file(Account.character, listener.addr[2], listener.addr[1], display_session: false)
      if custom_launch
        sal_filename = nil
        launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, game_key.to_s)
        scrubbed_launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, '[scrubbed key]')
        Lich.log "info: launcher_cmd: #{scrubbed_launcher_cmd}"
      else
        if RUBY_PLATFORM =~ /darwin/i
          localhost = "127.0.0.1"
        else
          localhost = "localhost"
        end
        @launch_data.collect! { |line| line.sub(/GAMEPORT=.+/, "GAMEPORT=#{localport}").sub(/GAMEHOST=.+/, "GAMEHOST=#{localhost}") }
        sal_filename = File.join(TEMP_DIR, "lich#{rand(10000)}.sal")
        while File.exist?(sal_filename)
          sal_filename = File.join(TEMP_DIR, "lich#{rand(10000)}.sal")
        end
        File.open(sal_filename, 'w') { |f| f.puts @launch_data }
        launcher_cmd = launcher_cmd.sub('%1', sal_filename)
        launcher_cmd = launcher_cmd.tr('/', "\\") if (RUBY_PLATFORM =~ /mingw|win/i) and (RUBY_PLATFORM !~ /darwin/i)
      end
      begin
        unless custom_launch_dir.nil? || custom_launch_dir.empty?
          Dir.chdir(custom_launch_dir)
        end

        frontend_pid = spawn(launcher_cmd)
        Lich::Common::Frontend.pid = frontend_pid if defined?(Lich::Common::Frontend)
      rescue
        Lich.log "error: #{$!.to_s.sub(game_key.to_s, '[scrubbed key]')}\n\t#{$!.backtrace.join("\n\t")}"
        Lich.msgbox(:message => "error: #{$!.to_s.sub(game_key.to_s, '[scrubbed key]')}", :icon => :error)
      end
      Lich.log 'info: waiting for client to connect...'
      300.times { sleep 0.1; break unless accept_thread.status }
      accept_thread.kill if accept_thread.status
      Dir.chdir(LICH_DIR)
      unless $_CLIENT_
        Lich.log "error: timeout waiting for client to connect"
        #        if defined?(Win32)
        #          Lich.msgbox(:message => "error: launch method #{method_num + 1} timed out waiting for the client to connect\n\nTry again and another method will be used.", :icon => :error)
        #        else
        Lich.msgbox(:message => "error: timeout waiting for client to connect", :icon => :error)
        #        end
        if sal_filename
          File.delete(sal_filename) # rescue() # rubocop complaint, but is it even necessary?
        end
        listener.close # rescue() # rubocop complaint, but is it even necessary?
        $_CLIENT_.close # rescue() # rubocop complaint, but is it even necessary?
        reconnect_if_wanted.call
        Lich.log "info: exiting..."
        Gtk.queue { Gtk.main_quit } if defined?(Gtk)
        exit
      end
      #      if defined?(Win32)
      #        Lich.win32_launch_method = "#{method_num}:success"
      #      end
      Lich.log 'info: connected'
      listener.close rescue nil
      if sal_filename
        File.delete(sal_filename) rescue nil
      end
    end
    gamehost, gameport = Lich.fix_game_host_port(gamehost, gameport)
    Lich.log "info: connecting to game server (#{gamehost}:#{gameport})"
    begin
      connect_thread = Thread.new {
        Game.open(gamehost, gameport)
      }
      300.times {
        sleep 0.1
        break unless connect_thread.status
      }
      if connect_thread.status
        connect_thread.kill rescue nil
        raise "error: timed out connecting to #{gamehost}:#{gameport}"
      end
    rescue
      Lich.log "error: #{$!}"
      gamehost, gameport = Lich.break_game_host_port(gamehost, gameport)
      Lich.log "info: connecting to game server (#{gamehost}:#{gameport})"
      begin
        connect_thread = Thread.new {
          Game.open(gamehost, gameport)
        }
        300.times {
          sleep 0.1
          break unless connect_thread.status
        }
        if connect_thread.status
          connect_thread.kill rescue nil
          raise "error: timed out connecting to #{gamehost}:#{gameport}"
        end
      rescue
        Lich.log "error: #{$!}"
        $_CLIENT_.close rescue nil
        reconnect_if_wanted.call
        Lich.log "info: exiting..."
        Gtk.queue { Gtk.main_quit } if defined?(Gtk)
        exit
      end
    end
    Lich.log 'info: connected'
  elsif @argv_options[:game_host] and @argv_options[:game_port]
    unless Lich.hosts_file
      Lich.log "error: cannot find hosts file"
      $stdout.puts "error: cannot find hosts file"
      exit
    end
    IPSocket.getaddress(@argv_options[:game_host])
    error_count = 0
    begin
      listener = TCPServer.new('127.0.0.1', @argv_options[:game_port])
      begin
        listener.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
      rescue
        Lich.log "warning: setsockopt with SO_REUSEADDR failed: #{$!}"
      end
    rescue
      sleep 1
      if (error_count += 1) >= 30
        $stdout.puts 'error: failed to bind to the proper port'
        Lich.log 'error: failed to bind to the proper port'
        exit!
      else
        retry
      end
    end
    Lich.modify_hosts(@argv_options[:game_host])

    $stdout.puts "Pretending to be #{@argv_options[:game_host]}"
    $stdout.puts "Listening on port #{@argv_options[:game_port]}"
    $stdout.puts "Waiting for the client to connect..."
    Lich.log "info: pretending to be #{@argv_options[:game_host]}"
    Lich.log "info: listening on port #{@argv_options[:game_port]}"
    Lich.log "info: waiting for the client to connect..."

    timeout_thread = Thread.new {
      sleep 120
      listener.close rescue nil
      $stdout.puts 'error: timed out waiting for client to connect'
      Lich.log 'error: timed out waiting for client to connect'
      Lich.restore_hosts
      exit
    }
    #      $_CLIENT_ = listener.accept
    $_CLIENT_ = SynchronizedSocket.new(listener.accept)
    listener.close rescue nil
    timeout_thread.kill
    $stdout.puts "Connection with the local game client is open."
    Lich.log "info: connection with the game client is open"
    Lich.restore_hosts
    if test_mode
      $_SERVER_ = $stdin # fixme
      $_CLIENT_.puts "Running in test mode: host socket set to stdin."
    else
      Lich.log 'info: connecting to the real game host...'
      @argv_options[:game_host], @argv_options[:game_port] = Lich.fix_game_host_port(@argv_options[:game_host], @argv_options[:game_port])
      begin
        timeout_thread = Thread.new {
          sleep 30
          Lich.log "error: timed out connecting to #{@argv_options[:game_host]}:#{@argv_options[:game_port]}"
          $stdout.puts "error: timed out connecting to #{@argv_options[:game_host]}:#{@argv_options[:game_port]}"
          exit
        }
        begin
          include Lich::Gemstone if @argv_options[:game_host] =~ /gs/i
          include Lich::DragonRealms if @argv_options[:game_host] =~ /dr/i
          Game.open(@argv_options[:game_host], @argv_options[:game_port])
        rescue
          Lich.log "error: #{$!}"
          $stdout.puts "error: #{$!}"
          exit
        end
        timeout_thread.kill rescue nil
        Lich.log 'info: connection with the game host is open'
      end
    end
  else
    # offline mode removed
    Lich.log "error: don't know what to do"
    exit
  end

  listener = nil

  # backward compatibility
  if $frontend =~ /^(?:wizard|avalon)$/
    $fake_stormfront = true
  else
    $fake_stormfront = false
  end

  undef :exit!

  if ARGV.include?('--without-frontend')
    Thread.new {
      #
      # send the login key
      #
      Game._puts(game_key)
      game_key = nil
      #
      # send version string
      #
      client_string = "/FE:WIZARD /VERSION:1.0.1.22 /P:#{RUBY_PLATFORM} /XML"
      $_CLIENTBUFFER_.push(client_string.dup)
      Game._puts(client_string)
      #
      # tell the server we're ready
      #
      2.times {
        sleep 0.3
        $_CLIENTBUFFER_.push("<c>\r\n")
        Game._puts("<c>")
      }
      $login_time = Time.now
    }
  else
    #
    # shutdown listening socket
    #
    error_count = 0
    begin
      # Somehow... for some ridiculous reason... Windows doesn't let us close the socket if we shut it down first...
      # listener.shutdown
      listener.close unless listener.closed?
    rescue
      Lich.log "warning: failed to close listener socket: #{$!}"
      if (error_count += 1) > 20
        Lich.log 'warning: giving up...'
      else
        sleep 0.05
        retry
      end
    end

    $stdout = $_CLIENT_
    $_CLIENT_.sync = true

    client_thread = Thread.new {
      $login_time = Time.now

      if $offline_mode
        # rubocop:disable Lint/Void
        nil
        # rubocop:enable Lint/Void
      elsif $frontend =~ /^(?:wizard|avalon)$/
        #
        # send the login key
        #
        client_string = $_CLIENT_.gets
        Game._puts(client_string)
        #
        # take the version string from the client, ignore it, and ask the server for xml
        #
        $_CLIENT_.gets
        client_string = "/FE:STORMFRONT /VERSION:1.0.1.26 /P:#{RUBY_PLATFORM} /XML"
        $_CLIENTBUFFER_.push(client_string.dup)
        Game._puts(client_string)
        #
        # tell the server we're ready
        #
        2.times {
          sleep 0.3
          $_CLIENTBUFFER_.push("#{$cmd_prefix}\r\n")
          Game._puts($cmd_prefix)
        }
        #
        # set up some stuff
        #
        for client_string in ["#{$cmd_prefix}_injury 2", "#{$cmd_prefix}_flag Display Inventory Boxes 1", "#{$cmd_prefix}_flag Display Dialog Boxes 0"]
          $_CLIENTBUFFER_.push(client_string)
          Game._puts(client_string)
        end
        #
        # client wants to send "GOOD", xml server won't recognize it
        # Avalon requires 2 gets to clear / Wizard only 1
        2.times { $_CLIENT_.gets } if $frontend =~ /avalon/i
        $_CLIENT_.gets if $frontend =~ /wizard/i
      elsif $frontend =~ /^(?:frostbite)$/
        #
        # send the login key
        #
        client_string = $_CLIENT_.gets
        client_string = fb_to_sf(client_string)
        Game._puts(client_string)
        #
        # take the version string from the client, ignore it, and ask the server for xml
        #
        $_CLIENT_.gets
        client_string = "/FE:STORMFRONT /VERSION:1.0.1.26 /P:#{RUBY_PLATFORM} /XML"
        $_CLIENTBUFFER_.push(client_string.dup)
        Game._puts(client_string)
        #
        # tell the server we're ready
        #
        2.times {
          sleep 0.3
          $_CLIENTBUFFER_.push("#{$cmd_prefix}\r\n")
          Game._puts($cmd_prefix)
        }
        #
        # set up some stuff
        #
        for client_string in ["#{$cmd_prefix}_injury 2", "#{$cmd_prefix}_flag Display Inventory Boxes 1", "#{$cmd_prefix}_flag Display Dialog Boxes 0"]
          $_CLIENTBUFFER_.push(client_string)
          Game._puts(client_string)
        end
      else
        if launcher_cmd =~ /mudlet/
          Game._puts(game_key)
          game_key = nil

          client_string = "/FE:WIZARD /VERSION:1.0.1.22 /P:#{RUBY_PLATFORM} /XML"
          $_CLIENTBUFFER_.push(client_string.dup)
          Game._puts(client_string)

          2.times {
            sleep 0.3
            $_CLIENTBUFFER_.push("<c>\r\n")
            Game._puts("<c>")
          }
        end
        inv_off_proc = proc { |server_string|
          if server_string =~ /^<(?:container|clearContainer|exposeContainer)/
            server_string.gsub!(/<(?:container|clearContainer|exposeContainer)[^>]*>|<inv.+\/inv>/, '')
            if server_string.empty?
              nil
            else
              server_string
            end
          elsif server_string =~ /^<flag id="Display Inventory Boxes" status='on' desc="Display all inventory and container windows."\/>/
            server_string.sub("status='on'", "status='off'")
          elsif server_string =~ /^\s*<d cmd="flag Inventory off">Inventory<\/d>\s+ON/
            server_string.sub("flag Inventory off", "flag Inventory on").sub('ON ', 'OFF')
          else
            server_string
          end
        }
        DownstreamHook.add('inventory_boxes_off', inv_off_proc)
        inv_toggle_proc = proc { |client_string_inv_toggle|
          if client_string_inv_toggle =~ /^(?:<c>)?_flag Display Inventory Boxes ([01])/
            if $1 == '1'
              DownstreamHook.remove('inventory_boxes_off')
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc)
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          elsif client_string_inv_toggle =~ /^(?:<c>)?\s*(?:set|flag)\s+inv(?:e|en|ent|ento|entor|entory)?\s+(on|off)/i
            if $1.downcase == 'on'
              DownstreamHook.remove('inventory_boxes_off')
              respond 'You have enabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc)
              respond 'You have disabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          else
            client_string_inv_toggle
          end
        }
        UpstreamHook.add('inventory_boxes_toggle', inv_toggle_proc)

        unless $offline_mode
          client_string = $_CLIENT_.gets
          Game._puts(client_string)
          client_string = $_CLIENT_.gets
          $_CLIENTBUFFER_.push(client_string.dup)
          Game._puts(client_string)
        end
      end

      begin
        while (client_string = $_CLIENT_.gets)
          if $frontend =~ /^(?:wizard|avalon)$/
            client_string = "#{$cmd_prefix}#{client_string}"
          elsif $frontend =~ /^(?:frostbite)$/
            client_string = fb_to_sf(client_string)
          end
          # Lich.log(client_string)
          begin
            $_IDLETIMESTAMP_ = Time.now
            do_client(client_string)
          rescue
            respond "--- Lich: error: client_thread: #{$!}"
            respond $!.backtrace.first
            Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      rescue
        respond "--- Lich: error: client_thread: #{$!}"
        respond $!.backtrace.first
        Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        sleep 0.2
        retry unless $_CLIENT_.closed? or Game.closed? or !Game.thread.alive? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed/i)
      ensure
        Frontend.cleanup_session_file
      end
      Game.close
    }
  end

  unless @argv_options[:detachable_client_port].nil?
    detachable_client_thread = Thread.new {
      loop {
        begin
          server = TCPServer.new(@argv_options[:detachable_client_host], @argv_options[:detachable_client_port])
          char_name = ARGV[ARGV.index('--login') + 1].capitalize
          Frontend.create_session_file(char_name, server.addr[2], server.addr[1])

          $_DETACHABLE_CLIENT_ = SynchronizedSocket.new(server.accept)
          $_DETACHABLE_CLIENT_.sync = true
        rescue
          Lich.log "#{$!}\n\t#{$!.backtrace.join("\n\t")}"
          server.close rescue nil
          $_DETACHABLE_CLIENT_.close rescue nil
          $_DETACHABLE_CLIENT_ = nil
          sleep 5
          next
        ensure
          server.close rescue nil
          Frontend.cleanup_session_file
        end
        if $_DETACHABLE_CLIENT_
          begin
            unless ARGV.include?('--genie')
              $frontend = 'profanity'
              Thread.new {
                100.times { sleep 0.1; break if XMLData.indicator['IconJOINED'] }
                init_str = "<progressBar id='mana' value='0' text='mana #{XMLData.mana}/#{XMLData.max_mana}'/>"
                init_str.concat "<progressBar id='health' value='0' text='health #{XMLData.health}/#{XMLData.max_health}'/>"
                init_str.concat "<progressBar id='spirit' value='0' text='spirit #{XMLData.spirit}/#{XMLData.max_spirit}'/>"
                init_str.concat "<progressBar id='stamina' value='0' text='stamina #{XMLData.stamina}/#{XMLData.max_stamina}'/>"
                init_str.concat "<spell>#{XMLData.prepared_spell}</spell>"
                for indicator in ['IconBLEEDING', 'IconPOISONED', 'IconDISEASED', 'IconSTANDING', 'IconKNEELING', 'IconSITTING', 'IconPRONE']
                  init_str.concat "<indicator id='#{indicator}' visible='#{XMLData.indicator[indicator]}'/>"
                end
                # These don't exist in DR.
                if XMLData.game =~ /GS/
                  init_str.concat "<progressBar id='pbarStance' value='#{XMLData.stance_value}'/>"
                  init_str.concat "<progressBar id='mindState' value='#{XMLData.mind_value}' text='#{XMLData.mind_text}'/>"
                  init_str.concat "<progressBar id='encumlevel' value='#{XMLData.encumbrance_value}' text='#{XMLData.encumbrance_text}'/>"
                  init_str.concat "<right>#{GameObj.right_hand.name}</right>"
                  init_str.concat "<left>#{GameObj.left_hand.name}</left>"
                  for area in ['back', 'leftHand', 'rightHand', 'head', 'rightArm', 'abdomen', 'leftEye', 'leftArm', 'chest', 'rightLeg', 'neck', 'leftLeg', 'nsys', 'rightEye']
                    if Wounds.send(area) > 0
                      init_str.concat "<image id=\"#{area}\" name=\"Injury#{Wounds.send(area)}\"/>"
                    elsif Scars.send(area) > 0
                      init_str.concat "<image id=\"#{area}\" name=\"Scar#{Scars.send(area)}\"/>"
                    end
                  end
                end
                init_str.concat '<compass>'
                shorten_dir = { 'north' => 'n', 'northeast' => 'ne', 'east' => 'e', 'southeast' => 'se', 'south' => 's', 'southwest' => 'sw', 'west' => 'w', 'northwest' => 'nw', 'up' => 'up', 'down' => 'down', 'out' => 'out' }
                for dir in XMLData.room_exits
                  if (short_dir = shorten_dir[dir])
                    init_str.concat "<dir value='#{short_dir}'/>"
                  end
                end
                init_str.concat '</compass>'
                $_DETACHABLE_CLIENT_.puts init_str
                nil
              }
            end
            while (client_string = $_DETACHABLE_CLIENT_.gets)
              # Profanity handshake:  SET_FRONTEND_PID <pid>
              if client_string =~ /^SET_FRONTEND_PID\s+(\d+)\s*$/
                Frontend.set_from_client($1.to_i) if defined?(Frontend)
                next # swallow the control line; don't pass it to do_client
              end
              client_string = "#{$cmd_prefix}#{client_string}" # if $frontend =~ /^(?:wizard|avalon)$/
              begin
                $_IDLETIMESTAMP_ = Time.now
                do_client(client_string)
              rescue
                respond "--- Lich: error: client_thread: #{$!}"
                respond $!.backtrace.first
                Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue
            respond "--- Lich: error: client_thread: #{$!}"
            respond $!.backtrace.first
            Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $_DETACHABLE_CLIENT_.close rescue nil
            $_DETACHABLE_CLIENT_ = nil
          ensure
            $_DETACHABLE_CLIENT_.close rescue nil
            $_DETACHABLE_CLIENT_ = nil
          end
        end
        sleep 0.1
      }
    }
  else
    detachable_client_thread = nil
  end

  wait_while { $offline_mode }

  if $frontend == 'wizard'
    $link_highlight_start = "\207".force_encoding(Encoding::ASCII_8BIT)
    $link_highlight_end = "\240".force_encoding(Encoding::ASCII_8BIT)
    $speech_highlight_start = "\212".force_encoding(Encoding::ASCII_8BIT)
    $speech_highlight_end = "\240".force_encoding(Encoding::ASCII_8BIT)
  end

  client_thread.priority = 3

  $_CLIENT_.puts "\n--- Lich v#{LICH_VERSION} is active.  Type #{$clean_lich_char}help for usage info.\n\n"

  Game.thread.join
  client_thread.kill rescue nil
  detachable_client_thread.kill rescue nil

  Lich.log 'info: stopping scripts...'
  Script.running.each { |script| script.kill }
  Script.hidden.each { |script| script.kill }
  200.times { sleep 0.1; break if Script.running.empty? and Script.hidden.empty? }
  Lich.log 'info: saving script settings...'
  Infomon::Monitor.save_proc if defined?(Infomon::Monitor)
  Settings.save
  Vars.save
  Lich.log 'info: closing connections...'
  Game.close
  200.times { sleep 0.1; break if Game.closed? }
  pause 0.5
  $_CLIENT_.close
  200.times { sleep 0.1; break if $_CLIENT_.closed? }
  Lich.db.close
  200.times { sleep 0.1; break if Lich.db.closed? }
  reconnect_if_wanted.call # taking this out of play but may need to see if anyone's using it
  Lich.log "info: exiting..."
  Gtk.queue { Gtk.main_quit } if defined?(Gtk)
  exit
}
