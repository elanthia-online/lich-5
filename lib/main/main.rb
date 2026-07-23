# Carve out for later carving and refining - main_thread and reconnect
# this needs work to break up and improve 2024-06-13

reconnect_if_wanted = proc {
  explicit_shutdown = Lich::Common::ShutdownCoordinator.orderly_user_exit?
  explicit_exit_buffered = $_CLIENTBUFFER_.any? { |cmd| Lich::Common::ShutdownIntent.user_exit_command?(cmd) }

  if ARGV.include?('--reconnect') and ARGV.include?('--login') and not explicit_shutdown and not explicit_exit_buffered
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
      if Frontend.client.eql?('stormfront')
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
  Thread.current.abort_on_exception = true # Propagate exceptions to main thread
  test_mode = false
  $SEND_CHARACTER = '>'
  $cmd_prefix = '<c>'
  $clean_lich_char = Frontend.client.eql?('genie') ? ',' : ';'
  $lich_char = Regexp.escape($clean_lich_char)
  $lich_char_regex = Regexp.union(',', ';')

  @launch_data = nil
  require File.join(LIB_DIR, 'common', 'authentication', 'eaccess.rb')
  require File.join(LIB_DIR, 'common', 'account.rb')
  # PipeIO is only consumed here (--pipe mode client adapter), so it loads with
  # main rather than from lich.rbw's top-level require chain -- that chain also
  # runs during self-update against older lib snapshots where pipe_io.rb may not
  # exist yet, and an unconditional require there would break the update path.
  require File.join(LIB_DIR, 'common', 'pipe_io.rb')
  # Lifecycle tracker is loaded here because startup context (argv/account)
  # and shutdown sequencing both live in main runtime orchestration.
  require File.join(LIB_DIR, 'common', 'best_effort_shutdown_cleanup.rb')
  require File.join(LIB_DIR, 'common', 'session_lifecycle.rb')
  require File.join(LIB_DIR, 'common', 'orderly_shutdown.rb')
  require File.join(LIB_DIR, 'common', 'shutdown_coordinator.rb')
  require File.join(LIB_DIR, 'common', 'shutdown_intent.rb')
  require File.join(LIB_DIR, 'common', 'shutdown_log.rb')
  require File.join(LIB_DIR, 'common', 'shutdown_script_drain.rb')
  require File.join(LIB_DIR, 'common', 'shutdown_watchdog.rb')

  run_orderly_user_shutdown = proc { |source: :primary_frontend|
    # Guard the user-initiated ("...exit") drain too: it kills scripts and runs
    # their before_dying hooks inline (any of which can hang) before the main
    # teardown/watchdog below is reached, so arm here as well. arm is
    # idempotent, so the later arm during teardown is a no-op. Both the primary
    # and detachable frontend exit paths route through here so neither can run
    # the hang-prone inline drain without the watchdog armed.
    Lich::Common::ShutdownWatchdog.arm if defined?(Lich::Common::ShutdownWatchdog)
    Lich::Common::OrderlyShutdown.request_user_exit(
      source: source,
      active_sessions_lifecycle: (Lich::InternalAPI::ActiveSessions::Lifecycle if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle))
    )
  }

  run_best_effort_shutdown_cleanup = proc {
    Lich::Common::BestEffortShutdownCleanup.run(
      coordinator: Lich::Common::ShutdownCoordinator,
      initial_scripts: (Script.running + Script.hidden),
      remaining_scripts: proc { Script.running + Script.hidden },
      script_drain: Lich::Common::ShutdownScriptDrain,
      vars: Vars,
      active_sessions_lifecycle: (Lich::InternalAPI::ActiveSessions::Lifecycle if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle))
    )
  }

  if ARGV.include?('--login')
    # CLI login flow: character authentication via saved entries
    require File.join(LIB_DIR, 'common', 'authentication', 'cli')

    # Extract character name from --login argument
    requested_character = ARGV[ARGV.index('--login') + 1].capitalize

    # Parse game code, frontend, and custom_launch from remaining arguments.
    # In headless mode, the requested frontend still matters to runtime startup
    # semantics, but it should not constrain saved-entry lookup.
    modifiers = ARGV.dup
    requested_instance, requested_fe, requested_custom_launch = Lich::Common::Authentication::LoginHelpers.resolve_login_args(modifiers)
    lookup_frontend = Lich::Common::Authentication::LoginHelpers.resolve_lookup_frontend(requested_fe, ARGV)

    # Execute CLI login flow and get launch data
    launch_data_array = if requested_character.match?(Lich::Common::Authentication::LoginHelpers::NEW_CHARACTER_LOGIN) && @argv_options[:account]
                          Lich::Common::Authentication::CLI.execute_new_character(
                            @argv_options[:account],
                            game_code: requested_instance,
                            frontend: requested_fe,
                            custom_launch: requested_custom_launch,
                            data_dir: DATA_DIR
                          )
                        else
                          Lich::Common::Authentication::CLI.execute(
                            requested_character,
                            game_code: requested_instance,
                            frontend: lookup_frontend,
                            custom_launch: requested_custom_launch,
                            data_dir: DATA_DIR
                          )
                        end

    if launch_data_array
      Lich.log "info: CLI login successful for #{requested_character}"
      @launch_data = launch_data_array
    else
      $stderr.puts "error: failed to authenticate for #{requested_character}"
      Lich.log "error: CLI login failed for #{requested_character}"
      $stderr.flush
      raise SystemExit.new(1) # With abort_on_exception=true, this propagates to main thread
    end

  ## GUI starts here

  elsif defined?(Gtk) and (ARGV.empty? or @argv_options[:gui])
    require File.join(LIB_DIR, 'common', 'gui_login.rb')
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
      modifiers = ARGV.dup
      Lich::Common::Authentication::LoginHelpers.resolve_login_args(modifiers)
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
      Frontend.client = if ARGV.any? { |a| a =~ /^--saga$/i }
                          'saga'
                        elsif @argv_options[:detachable_client_port] && !ARGV.any? { |a| a =~ /^--genie$/i }
                          'profanity'
                        else
                          'unknown'
                        end
      unless (game_key = @launch_data.find { |opt| opt =~ /KEY=/ }) && (game_key = game_key.split('=').last.chomp)
        $stdout.puts "error: launch_data contains no KEY info"
        Lich.log "error: launch_data contains no KEY info"
        exit(1)
      end
    elsif game =~ /SUKS/i
      Frontend.client = 'suks'
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
    elsif @argv_options[:pipe]
      # Use stdin/stdout as the client transport instead of a front-end socket.
      # Pair with -g HOST:PORT to connect directly to the game server (no SGE).
      # stdin supplies what a front-end would send (including the initial login
      # key); processed server output is written to stdout. EOF on stdin marks
      # the client dead (PipeIO#closed?) and triggers the normal shutdown path.
      Frontend.client = 'unknown'
      $_CLIENT_ = SynchronizedSocket.new(Lich::Common::PipeIO.new)
      Lich.log 'info: --pipe mode: using stdin/stdout as client transport'
    elsif Frontend.client.eql?('suks')
      nil
    else
      if game =~ /WIZ/i
        Frontend.client = 'wizard'
      elsif game =~ /STORM/i
        Frontend.client = 'stormfront'
      elsif game =~ /AVALON/i
        Frontend.client = 'avalon'
      elsif game =~ /SAGA/i
        Frontend.client = 'saga'
      else
        Frontend.client = 'unknown'
      end
      begin
        listener = TCPServer.new(@argv_options[:bind_address] || '127.0.0.1', nil)
      rescue
        $stdout.puts "--- error: cannot bind listen socket to local port: #{$!}"
        Lich.log "error: cannot bind listen socket to local port: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        exit(1)
      end
      accept_thread = Thread.new {
        accepted_socket, = listener.accept
        $_CLIENT_ = SynchronizedSocket.new(accepted_socket)
      }
      localport = listener.local_address.ip_port
      Frontend.create_session_file(Lich::Common::Account.character, listener.local_address.ip_address, localport, display_session: false)
      if custom_launch
        sal_filename = nil
        launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, game_key.to_s)
        scrubbed_launcher_cmd = custom_launch.sub(/\%port\%/, localport.to_s).sub(/\%key\%/, '[scrubbed key]')
        Lich.log "info: launcher_cmd: #{scrubbed_launcher_cmd}"
      else
        # GAMEHOST tells the spawned frontend where to connect. Mirror a specific
        # --bind-address (the listener only binds that one address), but fall back
        # to loopback for wildcard binds since a frontend cannot connect to 0.0.0.0/::.
        if @argv_options[:bind_address] && !%w[0.0.0.0 ::].include?(@argv_options[:bind_address])
          localhost = @argv_options[:bind_address]
        elsif RUBY_PLATFORM =~ /darwin/i
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
        Lich::Common.shutdown_gtk_before_exit
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
      Game.open_with_timeout(gamehost, gameport)
    rescue
      Lich.log "error: #{$!}"
      gamehost, gameport = Lich.break_game_host_port(gamehost, gameport)
      Lich.log "info: connecting to game server (#{gamehost}:#{gameport})"
      begin
        Game.open_with_timeout(gamehost, gameport)
      rescue
        Lich.log "error: #{$!}"
        $_CLIENT_.close rescue nil
        reconnect_if_wanted.call
        Lich.log "info: exiting..."
        Lich::Common.shutdown_gtk_before_exit
        exit
      end
    end
    Lich.log 'info: connected'
  elsif @argv_options[:pipe] and @argv_options[:game_host] and @argv_options[:game_port]
    # --pipe with -g: no front-end socket and no hosts-file redirection.
    # stdin/stdout act as the client transport; connect straight to the game
    # server named by -g (SGE/eaccess login already bypassed by -g). stdin
    # supplies the login key + version; processed server output goes to stdout.
    Frontend.client = 'unknown'
    $_CLIENT_ = SynchronizedSocket.new(Lich::Common::PipeIO.new)
    Lich.log 'info: --pipe mode: using stdin/stdout as client transport'
    @argv_options[:game_host], @argv_options[:game_port] = Lich.fix_game_host_port(@argv_options[:game_host], @argv_options[:game_port])
    # Bring a concrete Game class into scope so bare Game.* references (here and
    # in the client thread / shutdown) resolve to one consistent class. Prefer an
    # explicit --dragonrealms/--gemstone flag (useful when -g points at a loopback
    # host that can't be sniffed); otherwise fall back to the host name. The
    # actual game instance is still derived from the server's <settingsInfo>.
    if Lich::Common::Authentication::LoginHelpers.dragonrealms_flag?(ARGV) || @argv_options[:game_host] =~ /dr/i
      include Lich::DragonRealms
    else
      include Lich::Gemstone
    end
    Lich.log "info: connecting to game server (#{@argv_options[:game_host]}:#{@argv_options[:game_port]})"
    begin
      # Bounded connect so a stuck Game.open cannot hang pipe mode indefinitely on
      # an unreachable host.
      connect_thread = Thread.new {
        # report_on_exception off: a failed Game.open is surfaced by the join below
        # (which re-raises it), not by an auto-printed thread warning.
        Thread.current.report_on_exception = false
        Game.open(@argv_options[:game_host], @argv_options[:game_port])
      }
      # join(30) returns nil on timeout, the thread on success, and re-raises if
      # Game.open errored (e.g. connection refused) -- so a failed connect reaches
      # the rescue below instead of silently proceeding with a dead game socket.
      if connect_thread.join(30).nil?
        connect_thread.kill rescue nil
        raise "timed out connecting to #{@argv_options[:game_host]}:#{@argv_options[:game_port]}"
      end
    rescue
      Lich.log "error: #{$!}"
      $stdout.puts "error: #{$!}"
      $_CLIENT_.close rescue nil
      exit
    end
    Lich.log 'info: connection with the game host is open'
  elsif @argv_options[:game_host] and @argv_options[:game_port]
    unless Lich.hosts_file
      Lich.log "error: cannot find hosts file"
      $stdout.puts "error: cannot find hosts file"
      exit
    end
    IPSocket.getaddress(@argv_options[:game_host])
    error_count = 0
    begin
      listener = Lich::Common::ReusableTCPServer.create(@argv_options[:bind_address] || '127.0.0.1', @argv_options[:game_port])
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
    accepted_socket, = listener.accept
    $_CLIENT_ = SynchronizedSocket.new(accepted_socket)
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
      client_string = Frontend::CLIENT_STRING
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
    # shutdown listening socket (pipe mode never opened one)
    #
    unless @argv_options[:pipe]
      error_count = 0
      begin
        # Somehow... for some ridiculous reason... Windows doesn't let us close the socket if we shut it down first...
        # listener.shutdown
        listener.close if listener && !listener.closed?
      rescue
        Lich.log "warning: failed to close listener socket: #{$!}"
        if (error_count += 1) > 20
          Lich.log 'warning: giving up...'
        else
          sleep 0.05
          retry
        end
      end
    end

    $stdout = $_CLIENT_
    $_CLIENT_.sync = true

    client_thread = Thread.new {
      $login_time = Time.now

      if $offline_mode
        next nil
      elsif Frontend.supports_gsl?
        #
        # send the login key
        #
        client_string = $_CLIENT_.gets
        Game._puts(client_string)
        #
        # take the version string from the client, ignore it, and ask the server for xml
        #
        $_CLIENT_.gets
        Frontend.send_handshake(Frontend::CLIENT_STRING)
        #
        # client wants to send "GOOD", xml server won't recognize it
        # Avalon requires 2 gets to clear / Wizard only 1
        2.times { $_CLIENT_.gets } if Frontend.client.eql?('avalon')
        $_CLIENT_.gets if Frontend.client.eql?('wizard')
      elsif Frontend.client.eql?('frostbite')
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
        Frontend.send_handshake(Frontend::CLIENT_STRING)
      else
        if launcher_cmd =~ /mudlet/
          Game._puts(game_key)
          game_key = nil

          client_string = Frontend::CLIENT_STRING
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
        DownstreamHook.add('inventory_boxes_off', inv_off_proc, persist: true) # engine display toggle
        inv_toggle_proc = proc { |client_string_inv_toggle|
          if client_string_inv_toggle =~ /^(?:<c>)?_flag Display Inventory Boxes ([01])/
            if $1 == '1'
              DownstreamHook.remove('inventory_boxes_off')
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc, persist: true) # engine display toggle
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          elsif client_string_inv_toggle =~ /^(?:<c>)?\s*(?:set|flag)\s+inv(?:e|en|ent|ento|entor|entory)?\s+(on|off)/i
            if $1.downcase == 'on'
              DownstreamHook.remove('inventory_boxes_off')
              respond 'You have enabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, true)
            else
              DownstreamHook.add('inventory_boxes_off', inv_off_proc, persist: true) # engine display toggle
              respond 'You have disabled viewing of inventory and container windows.'
              Lich.set_inventory_boxes(XMLData.player_id, false)
            end
            nil
          else
            client_string_inv_toggle
          end
        }
        UpstreamHook.add('inventory_boxes_toggle', inv_toggle_proc, persist: true) # engine display toggle

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
          if Frontend.supports_gsl?
            client_string = "#{$cmd_prefix}#{client_string}"
          elsif Frontend.client.eql?('frostbite')
            client_string = fb_to_sf(client_string)
          end
          if Lich::Common::ShutdownIntent.user_exit_command?(client_string)
            run_orderly_user_shutdown.call
            break
          end
          # Lich.log(client_string)
          begin
            dispatch_client_input(client_string)
          rescue
            respond "--- Lich: error: client_thread: #{$!}"
            respond $!.backtrace.first
            Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          end
        end
      rescue
        _respond "--- Lich: error: client_thread: #{$!}"
        Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        sleep 0.2
        retry unless !$_CLIENT_.alive? or Game.closed? or !Game.thread.alive? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed/i)
      ensure
        Frontend.cleanup_session_file
      end
      Lich::Common::ShutdownCoordinator.request(reason: :client_disconnect, source: :primary_frontend)
      Game.close
    }
  end

  session_name = Lich::InternalAPI::ActiveSessions::Lifecycle.resolve_session_name(
    argv: ARGV,
    account_character: (Lich::Common::Account.character rescue nil)
  )
  session_role = Lich::InternalAPI::ActiveSessions::Lifecycle.resolve_role(
    argv: ARGV,
    detachable_client_port: @argv_options[:detachable_client_port]
  )
  Lich::InternalAPI::ActiveSessions::Lifecycle.start(session_name: session_name, role: session_role)

  unless @argv_options[:detachable_client_port].nil?
    detachable_client_thread = Thread.new {
      server = nil
      begin
        loop {
          begin
            if server.nil? || server.closed?
              server = Lich::Common::ReusableTCPServer.create(
                @argv_options[:detachable_client_host],
                @argv_options[:detachable_client_port],
                backlog: 8
              )
              $_DETACHABLE_LISTENER_ = {
                host: server.local_address.ip_address,
                port: server.local_address.ip_port
              }
              login_idx = ARGV.index('--login')
              char_name = if !login_idx.nil? && ARGV[login_idx + 1]
                            ARGV[login_idx + 1].capitalize
                          end

              begin
                Frontend.create_session_file(char_name, $_DETACHABLE_LISTENER_[:host], $_DETACHABLE_LISTENER_[:port]) if char_name
              rescue => e
                Lich.log "warning: failed to create session file: #{e}\n\t#{e.backtrace.join("\n\t")}"
              end
              detachable_listener_connected(detachable_client_count.positive?)

              listen_ip = $_DETACHABLE_LISTENER_[:host]
              listen_ip = "[#{listen_ip}]" if server.local_address.ipv6?
              listen_address = "#{listen_ip}:#{$_DETACHABLE_LISTENER_[:port]}"
              Lich.log "info: detachable client server listening on #{listen_address}"
              $stdout.puts "--- Lich: detachable client listening on #{listen_address}" rescue nil
            end

            accepted_socket, = server.accept
            client = SynchronizedSocket.new(accepted_socket, role: :detachable)
            client.sync = true
            detachable_client_register(client)
            Lich.log "info: detachable client connected (#{detachable_client_count} attached)"
            Thread.new(client) { |attached_client| handle_detachable_client(attached_client) }
          rescue => e
            break if Lich::Common::ShutdownCoordinator.orderly_user_exit?

            Lich.log "error: detachable_client_thread (accept): #{e}\n\t#{e.backtrace.join("\n\t")}"
            server.close rescue nil
            server = nil
            Lich::InternalAPI::ActiveSessions::Lifecycle.clear_listener
            sleep 5
          end
          break if Lich::Common::ShutdownCoordinator.orderly_user_exit?
        }
      ensure
        server.close rescue nil
        $_DETACHABLE_LISTENER_ = nil
        Lich::InternalAPI::ActiveSessions::Lifecycle.clear_listener
        begin
          Frontend.cleanup_session_file
        rescue => cleanup_error
          Lich::Common::ShutdownLog.warning("failed to cleanup session file: #{cleanup_error}\n\t#{cleanup_error.backtrace.join("\n\t")}")
        end
      end
    }
  else
    detachable_client_thread = nil
  end

  # Start process lifecycle reporting after core sockets/threads are initialized.
  # Registration itself is deferred by SessionLifecycle to wait for XML game context.
  session_name = Lich::Common::SessionLifecycle.resolve_session_name(
    argv: ARGV,
    account_character: (Lich::Common::Account.character rescue nil)
  )
  session_role = Lich::Common::SessionLifecycle.resolve_role(
    argv: ARGV,
    detachable_client_port: @argv_options[:detachable_client_port]
  )
  Lich::Common::SessionLifecycle.start(session_name: session_name, role: session_role)
  begin
    wait_while { $offline_mode }

    if Frontend.client.eql?('wizard')
      $link_highlight_start = "\207".force_encoding(Encoding::ASCII_8BIT)
      $link_highlight_end = "\240".force_encoding(Encoding::ASCII_8BIT)
      $speech_highlight_start = "\212".force_encoding(Encoding::ASCII_8BIT)
      $speech_highlight_end = "\240".force_encoding(Encoding::ASCII_8BIT)
    end

    client_thread.priority = 3

    $_CLIENT_.puts "\n--- Lich v#{LICH_VERSION} is active.  Type #{$clean_lich_char}help for usage info.\n\n"

    Game.thread.join

    shutdown_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    shutdown_step_index = 0
    shutdown_trace_needed = false
    shutdown_trace = []
    shutdown_total_trace_threshold = 3.0
    shutdown_step_trace_thresholds = {
      'Vars.save'     => 0.5,
      'Lich.db.close' => 0.5
    }

    shutdown_step = proc { |description, details: nil, &block|
      shutdown_step_index += 1
      step_index = shutdown_step_index
      step_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      step_failed = false

      begin
        block.call
      rescue StandardError => e
        step_failed = true
        shutdown_trace_needed = true
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - step_started_at
        Lich::Common::ShutdownLog.warning("#{description} failed during shutdown after #{format('%.3f', elapsed)}s: #{e.class}: #{e.message}")
      ensure
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - step_started_at
        total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - shutdown_started_at
        threshold = shutdown_step_trace_thresholds.fetch(description, 0.75)
        detail_text = nil

        if details
          begin
            detail_text = details.respond_to?(:call) ? details.call : details
          rescue StandardError => e
            shutdown_trace_needed = true
            detail_text = "shutdown_details_error=#{e.class}: #{e.message}"
          end
        end

        trace_details = detail_text.to_s.empty? ? '' : " #{detail_text}"
        if !step_failed && elapsed >= threshold
          shutdown_trace_needed = true
          Lich::Common::ShutdownLog.warning("shutdown step #{description} exceeded #{format('%.3f', threshold)}s threshold elapsed=#{format('%.3f', elapsed)}s")
        end
        shutdown_trace << "shutdown[#{step_index}] #{description} #{step_failed ? 'failed' : 'finished'} elapsed=#{format('%.3f', elapsed)}s total=#{format('%.3f', total)}s#{trace_details}"
      end
    }

    flush_shutdown_trace = proc {
      total = Process.clock_gettime(Process::CLOCK_MONOTONIC) - shutdown_started_at
      if total >= shutdown_total_trace_threshold
        shutdown_trace_needed = true
        Lich::Common::ShutdownLog.warning("shutdown exceeded #{format('%.3f', shutdown_total_trace_threshold)}s threshold total=#{format('%.3f', total)}s")
      end
      next unless shutdown_trace_needed

      Lich::Common::ShutdownLog.debug("shutdown trace total=#{format('%.3f', total)}s")
      shutdown_trace.each { |trace_line| Lich::Common::ShutdownLog.debug(trace_line) }
    }

    # ActiveSessions exposes two distinct signals:
    #
    # * registry presence: this Lich process is still known to the
    #   active-sessions service
    # * connected: the game/session connection is still available for normal
    #   use
    #
    # MahtraDR's shutdown testing showed that immediate unregister solves stale
    # listings but changes the API meaning by making a still-closing process
    # disappear.  Marking the session disconnected here preserves the sharper
    # contract: external tooling can see that the game connection ended while
    # Lich continues script before_dying hooks, Vars.save, socket closeout, and
    # database closeout.  Lifecycle.stop remains later in shutdown and is the
    # point where this process is removed from the ActiveSessions registry.
    # Guard the teardown steps below: several (inline before_dying/at_exit
    # script hooks, Vars.save, Game.close linger, database close, lifecycle
    # unregister IO) have no individual timeout and can hang, leaving the
    # process alive and holding its sockets. The watchdog dumps thread
    # backtraces and forces exit if teardown stalls; it is disarmed once the
    # unbounded steps complete, before the deliberate reconnect/exec path.
    Lich::Common::ShutdownWatchdog.arm if defined?(Lich::Common::ShutdownWatchdog)

    Lich::Common::ShutdownLog.info('marking session disconnected...')
    shutdown_step.call('ActiveSessions connection update') do
      Lich::InternalAPI::ActiveSessions::Lifecycle.update_connected(false) if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
    end

    if Lich::Common::ShutdownCoordinator.connection_loss? &&
       !(Lich::Common::ShutdownCoordinator.scripts_drained? && Lich::Common::ShutdownCoordinator.vars_saved?)
      run_best_effort_shutdown_cleanup.call
    end

    if Lich::Common::ShutdownCoordinator.scripts_drained?
      Lich::Common::ShutdownLog.info('script shutdown already completed before closing game connection...')
    else
      script_shutdown_result = nil
      shutdown_step.call('script shutdown', details: proc { script_shutdown_result&.details }) do
        Lich::Common::ShutdownLog.info('stopping scripts...')
        # Shutdown context preserves before_dying/at_exit handlers while skipping
        # MemoryReleaser work; process exit will reclaim memory.
        # Individual script names are reported at 2x the step threshold so normal
        # teardown stays quiet while slow exits remain visible.
        script_shutdown_slow_threshold = shutdown_step_trace_thresholds.fetch('script shutdown', 0.75) * 2
        script_shutdown_result = Lich::Common::ShutdownScriptDrain.run(
          initial_scripts: (Script.running + Script.hidden),
          remaining_scripts: proc { Script.running + Script.hidden },
          slow_threshold: script_shutdown_slow_threshold
        )
      end
    end
    if Lich::Common::ShutdownCoordinator.vars_saved?
      Lich::Common::ShutdownLog.info('script settings already saved before closing game connection...')
    else
      Lich::Common::ShutdownLog.info('saving script settings...')
      shutdown_step.call('Vars.save') { Vars.save }
    end
    Lich::Common::ShutdownLog.info('closing connections...')
    shutdown_step.call('Game.close') { Game.close }
    shutdown_step.call('client_thread.kill') { client_thread.kill }
    shutdown_step.call('detachable_client_thread.kill') do
      if detachable_client_thread
        detachable_client_thread.kill
        detachable_client_thread.join
      end
    end
    shutdown_step.call('detachable clients close') { detachable_clients_close }
    shutdown_step.call('$_CLIENT_.close') { $_CLIENT_&.close }
    shutdown_step.call('Lich.db.close') { Lich.db.close }
    Lich::Common::ShutdownLog.info('unregistering session...')
    shutdown_step.call('ActiveSessions lifecycle stop') do
      Lich::InternalAPI::ActiveSessions::Lifecycle.stop if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
    end
    shutdown_step.call('SessionLifecycle stop') do
      Lich::Common::SessionLifecycle.stop if defined?(Lich::Common::SessionLifecycle)
    end
    # Unbounded teardown is complete; stand down before the deliberate
    # reconnect sleep/exec and process exit so neither is force-killed.
    Lich::Common::ShutdownWatchdog.disarm if defined?(Lich::Common::ShutdownWatchdog)
    flush_shutdown_trace.call
    shutdown_step.call('reconnect hook') { reconnect_if_wanted.call } # keep after closeout; may launch a replacement session
    clean_user_shutdown = Lich::Common::ShutdownCoordinator.orderly_user_exit? &&
                          Lich::Common::ShutdownCoordinator.orderly_shutdown_completed? &&
                          Lich::Common::ShutdownCoordinator.scripts_drained? &&
                          Lich::Common::ShutdownCoordinator.vars_saved? &&
                          Lich::Common::ShutdownCoordinator.best_effort_cleanup_result.nil? &&
                          !Lich::Common::ShutdownCoordinator.client_socket_write_failed? &&
                          !shutdown_trace_needed
    if clean_user_shutdown
      Lich::Common::ShutdownLog.complete_user_exit_summary('user-initiated shutdown completed cleanly')
    else
      Lich::Common::ShutdownLog.flush_user_exit_summary!
    end
    Lich::Common::ShutdownLog.info('exiting...')
    Lich::Common.shutdown_gtk_before_exit
    exit
  ensure
    # Guarantee lifecycle stop even on abnormal exit (e.g. abort_on_exception).
    # Both .stop methods are idempotent -- safe to call if already stopped.
    Lich::Common::ShutdownLog.flush_user_exit_summary! rescue nil
    Lich::InternalAPI::ActiveSessions::Lifecycle.stop rescue nil if defined?(Lich::InternalAPI::ActiveSessions::Lifecycle)
    Lich::Common::SessionLifecycle.stop rescue nil if defined?(Lich::Common::SessionLifecycle)
  end
}
