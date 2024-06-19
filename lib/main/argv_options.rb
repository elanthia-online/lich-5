# break out for CLI options selected at launch
# 2024-06-13

ARGV.delete_if { |arg| arg =~ /launcher\.exe/i } # added by Simutronics Game Entry

@argv_options = Hash.new
bad_args = Array.new

for arg in ARGV
  if (arg == '-h') or (arg == '--help')
    puts 'Usage:  lich [OPTION]'
    puts ''
    puts 'Options are:'
    puts '  -h, --help            Display this list.'
    puts '  -V, --version         Display the program version number and credits.'
    puts ''
    puts '  -d, --directory       Set the main Lich program directory.'
    puts '      --script-dir      Set the directoy where Lich looks for scripts.'
    puts '      --data-dir        Set the directory where Lich will store script data.'
    puts '      --temp-dir        Set the directory where Lich will store temporary files.'
    puts ''
    puts '  -w, --wizard          Run in Wizard mode (default)'
    puts '  -s, --stormfront      Run in StormFront mode.'
    puts '      --avalon          Run in Avalon mode.'
    puts '      --frostbite       Run in Frosbite mode.'
    puts ''
    puts '      --dark-mode       Enable/disable darkmode without GUI. See example below.'
    puts ''
    puts '      --gemstone        Connect to the Gemstone IV Prime server (default).'
    puts '      --dragonrealms    Connect to the DragonRealms server.'
    puts '      --platinum        Connect to the Gemstone IV/DragonRealms Platinum server.'
    puts '      --test            Connect to the test instance of the selected game server.'
    puts '  -g, --game            Set the IP address and port of the game.  See example below.'
    puts ''
    puts '      --install         Edits the Windows/WINE registry so that Lich is started when logging in using the website or SGE.'
    puts '      --uninstall       Removes Lich from the registry.'
    puts ''
    puts 'The majority of Lich\'s built-in functionality was designed and implemented with Simutronics MUDs in mind (primarily Gemstone IV): as such, many options/features provided by Lich may not be applicable when it is used with a non-Simutronics MUD.  In nearly every aspect of the program, users who are not playing a Simutronics game should be aware that if the description of a feature/option does not sound applicable and/or compatible with the current game, it should be assumed that the feature/option is not.  This particularly applies to in-script methods (commands) that depend heavily on the data received from the game conforming to specific patterns (for instance, it\'s extremely unlikely Lich will know how much "health" your character has left in a non-Simutronics game, and so the "health" script command will most likely return a value of 0).'
    puts ''
    puts 'The level of increase in efficiency when Lich is run in "bare-bones mode" (i.e. started with the --bare argument) depends on the data stream received from a given game, but on average results in a moderate improvement and it\'s recommended that Lich be run this way for any game that does not send "status information" in a format consistent with Simutronics\' GSL or XML encoding schemas.'
    puts ''
    puts ''
    puts 'Examples:'
    puts '  lich -w -d /usr/bin/lich/          (run Lich in Wizard mode using the dir \'/usr/bin/lich/\' as the program\'s home)'
    puts '  lich -g gs3.simutronics.net:4000   (run Lich using the IP address \'gs3.simutronics.net\' and the port number \'4000\')'
    puts '  lich --dragonrealms --test --genie (run Lich connected to DragonRealms Test server for the Genie frontend)'
    puts '  lich --script-dir /mydir/scripts   (run Lich with its script directory set to \'/mydir/scripts\')'
    puts '  lich --bare -g skotos.net:5555     (run in bare-bones mode with the IP address and port of the game set to \'skotos.net:5555\')'
    puts '  lich --login YourCharName --detachable-client=8000 --without-frontend --dark-mode=true'
    puts '       ... (run Lich and login without the GUI in a headless state while enabling dark mode for Lich spawned windows)'
    puts ''
    exit
  elsif (arg == '-v') or (arg == '--version')
    puts "The Lich, version #{LICH_VERSION}"
    puts ' (an implementation of the Ruby interpreter by Yukihiro Matsumoto designed to be a \'script engine\' for text-based MUDs)'
    puts ''
    puts '- The Lich program and all material collectively referred to as "The Lich project" is copyright (C) 2005-2006 Murray Miron.'
    puts '- The Gemstone IV and DragonRealms games are copyright (C) Simutronics Corporation.'
    puts '- The Wizard front-end and the StormFront front-end are also copyrighted by the Simutronics Corporation.'
    puts '- Ruby is (C) Yukihiro \'Matz\' Matsumoto.'
    puts ''
    puts 'Thanks to all those who\'ve reported bugs and helped me track down problems on both Windows and Linux.'
    exit
  elsif arg == '--link-to-sge'
    result = Lich.link_to_sge
    if $stdout.isatty
      if result
        $stdout.puts "Successfully linked to SGE."
      else
        $stdout.puts "Failed to link to SGE."
      end
    end
    exit
  elsif arg == '--unlink-from-sge'
    result = Lich.unlink_from_sge
    if $stdout.isatty
      if result
        $stdout.puts "Successfully unlinked from SGE."
      else
        $stdout.puts "Failed to unlink from SGE."
      end
    end
    exit
  elsif arg == '--link-to-sal'
    result = Lich.link_to_sal
    if $stdout.isatty
      if result
        $stdout.puts "Successfully linked to SAL files."
      else
        $stdout.puts "Failed to link to SAL files."
      end
    end
    exit
  elsif arg == '--unlink-from-sal'
    result = Lich.unlink_from_sal
    if $stdout.isatty
      if result
        $stdout.puts "Successfully unlinked from SAL files."
      else
        $stdout.puts "Failed to unlink from SAL files."
      end
    end
    exit
  elsif arg == '--install' # deprecated
    if Lich.link_to_sge and Lich.link_to_sal
      $stdout.puts 'Install was successful.'
      Lich.log 'Install was successful.'
    else
      $stdout.puts 'Install failed.'
      Lich.log 'Install failed.'
    end
    exit
  elsif arg == '--uninstall' # deprecated
    if Lich.unlink_from_sge and Lich.unlink_from_sal
      $stdout.puts 'Uninstall was successful.'
      Lich.log 'Uninstall was successful.'
    else
      $stdout.puts 'Uninstall failed.'
      Lich.log 'Uninstall failed.'
    end
    exit
  elsif arg =~ /^--start-scripts=(.+)$/i
    @argv_options[:start_scripts] = $1
  elsif arg =~ /^--reconnect$/i
    @argv_options[:reconnect] = true
  elsif arg =~ /^--reconnect-delay=(.+)$/i
    @argv_options[:reconnect_delay] = $1
  elsif arg =~ /^--host=(.+):(.+)$/
    @argv_options[:host] = { :domain => $1, :port => $2.to_i }
  elsif arg =~ /^--hosts-file=(.+)$/i
    @argv_options[:hosts_file] = $1
  elsif arg =~ /^--no-gui$/i
    @argv_options[:gui] = false
  elsif arg =~ /^--gui$/i
    @argv_options[:gui] = true
  elsif arg =~ /^--game=(.+)$/i
    @argv_options[:game] = $1
  elsif arg =~ /^--account=(.+)$/i
    @argv_options[:account] = $1
  elsif arg =~ /^--password=(.+)$/i
    @argv_options[:password] = $1
  elsif arg =~ /^--character=(.+)$/i
    @argv_options[:character] = $1
  elsif arg =~ /^--frontend=(.+)$/i
    @argv_options[:frontend] = $1
  elsif arg =~ /^--frontend-command=(.+)$/i
    @argv_options[:frontend_command] = $1
  elsif arg =~ /^--save$/i
    @argv_options[:save] = true
  elsif arg =~ /^--wine(?:\-prefix)?=.+$/i
    nil # already used when defining the Wine module
  elsif arg =~ /\.sal$|Gse\.~xt$/i
    @argv_options[:sal] = arg
    unless File.exist?(@argv_options[:sal])
      if ARGV.join(' ') =~ /([A-Z]:\\.+?\.(?:sal|~xt))/i
        @argv_options[:sal] = $1
      end
    end
    unless File.exist?(@argv_options[:sal])
      if defined?(Wine)
        @argv_options[:sal] = "#{Wine::PREFIX}/drive_c/#{@argv_options[:sal][3..-1].split('\\').join('/')}"
      end
    end
    bad_args.clear
  elsif arg =~ /^--dark-mode=(true|false|on|off)$/i
    value = $1
    if value =~ /^(true|on)$/i
      @argv_options[:dark_mode] = true
    elsif value =~ /^(false|off)$/i
      @argv_options[:dark_mode] = false
    end
    if defined?(Gtk)
      @theme_state = Lich.track_dark_mode = @argv_options[:dark_mode]
    end
  else
    bad_args.push(arg)
  end
end
# rubocop:disable Lint/UselessAssignment

if (arg = ARGV.find { |a| a == '--hosts-dir' })
  i = ARGV.index(arg)
  ARGV.delete_at(i)
  hosts_dir = ARGV[i]
  ARGV.delete_at(i)
  if hosts_dir and File.exist?(hosts_dir)
    hosts_dir = hosts_dir.tr('\\', '/')
    hosts_dir += '/' unless hosts_dir[-1..-1] == '/'
  else
    $stdout.puts "warning: given hosts directory does not exist: #{hosts_dir}"
    hosts_dir = nil
  end
else
  hosts_dir = nil
end

@detachable_client_host = '127.0.0.1'
@detachable_client_port = nil
if (arg = ARGV.find { |a| a =~ /^\-\-detachable\-client=[0-9]+$/ })
  @detachable_client_port = /^\-\-detachable\-client=([0-9]+)$/.match(arg).captures.first
elsif (arg = ARGV.find { |a| a =~ /^\-\-detachable\-client=((?:\d{1,3}\.){3}\d{1,3}):([0-9]{1,5})$/ })
  @detachable_client_host, @detachable_client_port = /^\-\-detachable\-client=((?:\d{1,3}\.){3}\d{1,3}):([0-9]{1,5})$/.match(arg).captures
end

if @argv_options[:sal]
  unless File.exist?(@argv_options[:sal])
    Lich.log "error: launch file does not exist: #{@argv_options[:sal]}"
    Lich.msgbox "error: launch file does not exist: #{@argv_options[:sal]}"
    exit
  end
  Lich.log "info: launch file: #{@argv_options[:sal]}"
  if @argv_options[:sal] =~ /SGE\.sal/i
    unless (launcher_cmd = Lich.get_simu_launcher)
      $stdout.puts 'error: failed to find the Simutronics launcher'
      Lich.log 'error: failed to find the Simutronics launcher'
      exit
    end
    launcher_cmd.sub!('%1', @argv_options[:sal])
    Lich.log "info: launcher_cmd: #{launcher_cmd}"
    if defined?(Win32) and launcher_cmd =~ /^"(.*?)"\s*(.*)$/
      dir_file = $1
      param = $2
      dir = dir_file.slice(/^.*[\\\/]/)
      file = dir_file.sub(/^.*[\\\/]/, '')
      operation = (Win32.isXP? ? 'open' : 'runas')
      Win32.ShellExecute(:lpOperation => operation, :lpFile => file, :lpDirectory => dir, :lpParameters => param)
      if r < 33
        Lich.log "error: Win32.ShellExecute returned #{r}; Win32.GetLastError: #{Win32.GetLastError}"
      end
    elsif defined?(Wine)
      system("#{Wine::BIN} #{launcher_cmd}")
    else
      system(launcher_cmd)
    end
    exit
  end
end

if (arg = ARGV.find { |a| (a == '-g') or (a == '--game') })
  game_host, game_port = ARGV[ARGV.index(arg) + 1].split(':')
  game_port = game_port.to_i
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    $frontend = 'stormfront'
  elsif ARGV.any? { |arg| (arg == '-w') or (arg == '--wizard') }
    $frontend = 'wizard'
  elsif ARGV.any? { |arg| arg == '--avalon' }
    $frontend = 'avalon'
  elsif ARGV.any? { |arg| arg == '--frostbite' }
    $frontend = 'frostbite'
  else
    $frontend = 'unknown'
  end
elsif ARGV.include?('--gemstone')
  if ARGV.include?('--platinum')
    $platinum = true
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      game_host = 'storm.gs4.game.play.net'
      game_port = 10124
      $frontend = 'stormfront'
    else
      game_host = 'gs-plat.simutronics.net'
      game_port = 10121
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      else
        $frontend = 'wizard'
      end
    end
  else
    $platinum = false
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      game_host = 'storm.gs4.game.play.net'
      game_port = 10024
      $frontend = 'stormfront'
    else
      game_host = 'gs3.simutronics.net'
      game_port = 4900
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      else
        $frontend = 'wizard'
      end
    end
  end
elsif ARGV.include?('--shattered')
  $platinum = false
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    game_host = 'storm.gs4.game.play.net'
    game_port = 10324
    $frontend = 'stormfront'
  else
    game_host = 'gs4.simutronics.net'
    game_port = 10321
    if ARGV.any? { |arg| arg == '--avalon' }
      $frontend = 'avalon'
    else
      $frontend = 'wizard'
    end
  end
elsif ARGV.include?('--fallen')
  $platinum = false
  # Not sure what the port info is for anything else but Genie :(
  if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
    $frontend = 'stormfront'
    $stdout.puts "fixme"
    Lich.log "fixme"
    exit
  elsif ARGV.grep(/--genie/).any?
    game_host = 'dr.simutronics.net'
    game_port = 11324
    $frontend = 'genie'
  else
    $stdout.puts "fixme"
    Lich.log "fixme"
    exit
  end
elsif ARGV.include?('--dragonrealms')
  if ARGV.include?('--platinum')
    $platinum = true
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      $frontend = 'stormfront'
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
    elsif ARGV.grep(/--genie/).any?
      game_host = 'dr.simutronics.net'
      game_port = 11124
      $frontend = 'genie'
    elsif ARGV.grep(/--frostbite/).any?
      game_host = 'dr.simutronics.net'
      game_port = 11124
      $frontend = 'frostbite'
    else
      $frontend = 'wizard'
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
    end
  else
    $platinum = false
    if ARGV.any? { |arg| (arg == '-s') or (arg == '--stormfront') }
      $frontend = 'stormfront'
      $stdout.puts "fixme"
      Lich.log "fixme"
      exit
    elsif ARGV.grep(/--genie/).any?
      game_host = 'dr.simutronics.net'
      game_port = ARGV.include?('--test') ? 11624 : 11024
      $frontend = 'genie'
    else
      game_host = 'dr.simutronics.net'
      game_port = ARGV.include?('--test') ? 11624 : 11024
      if ARGV.any? { |arg| arg == '--avalon' }
        $frontend = 'avalon'
      elsif ARGV.any? { |arg| arg == '--frostbite' }
        $frontend = 'frostbite'
      else
        $frontend = 'wizard'
      end
    end
  end
else
  game_host, game_port = nil, nil
  Lich.log "info: no force-mode info given"
end
# rubocop:enable Lint/UselessAssignment
