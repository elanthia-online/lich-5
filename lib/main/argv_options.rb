# frozen_string_literal: true

# CLI argument processing and orchestration (Layer 2)
# Three-layer architecture:
#   - Layer 1 (Opts): Pure parsing of ARGV → frozen OpenStruct
#   - Layer 2 (this file): Validation, routing to handlers, side effects
#   - Layer 3 (CliPasswordManager): Domain-specific handlers

require File.join(LIB_DIR, 'util', 'opts.rb')
require File.join(LIB_DIR, 'common', 'cli', 'cli_orchestration.rb')

module Lich
  module Main
    # Orchestrates ARGV processing: parsing → validation → handler execution → side effects
    module ArgvOptions
      # CLI operations are now handled by lib/common/cli/cli_orchestration.rb
      # which handles early-exit operations (password mgmt, conversion)
      # before normal argv_options processing

      # Parse ARGV and build @argv_options hash for backward compatibility
      module OptionParser
        def self.execute
          @argv_options = {}
          bad_args = []

          ARGV.each do |arg|
            case arg
            when '-h', '--help'
              print_help
              exit
            when '-v', '--version'
              print_version
              exit
            when '--link-to-sge'
              result = Lich.link_to_sge
              $stdout.puts(result ? 'Successfully linked to SGE.' : 'Failed to link to SGE.') if $stdout.isatty
              exit
            when '--unlink-from-sge'
              result = Lich.unlink_from_sge
              $stdout.puts(result ? 'Successfully unlinked from SGE.' : 'Failed to unlink from SGE.') if $stdout.isatty
              exit
            when '--link-to-sal'
              result = Lich.link_to_sal
              $stdout.puts(result ? 'Successfully linked to SAL files.' : 'Failed to link to SAL files.') if $stdout.isatty
              exit
            when '--unlink-from-sal'
              result = Lich.unlink_from_sal
              $stdout.puts(result ? 'Successfully unlinked from SAL files.' : 'Failed to unlink from SAL files.') if $stdout.isatty
              exit
            when '--install'
              if Lich.link_to_sge && Lich.link_to_sal
                $stdout.puts 'Install was successful.'
                Lich.log 'Install was successful.'
              else
                $stdout.puts 'Install failed.'
                Lich.log 'Install failed.'
              end
              exit
            when '--uninstall'
              if Lich.unlink_from_sge && Lich.unlink_from_sal
                $stdout.puts 'Uninstall was successful.'
                Lich.log 'Uninstall was successful.'
              else
                $stdout.puts 'Uninstall failed.'
                Lich.log 'Uninstall failed.'
              end
              exit
            when /^--start-scripts=(.+)$/i
              @argv_options[:start_scripts] = $1
            when /^--reconnect$/i
              @argv_options[:reconnect] = true
            when /^--reconnect-delay=(.+)$/i
              @argv_options[:reconnect_delay] = $1
            when /^--host=(.+):(.+)$/
              @argv_options[:host] = { domain: $1, port: $2.to_i }
            when /^--hosts-file=(.+)$/i
              @argv_options[:hosts_file] = $1
            when /^--no-gui$/i
              @argv_options[:gui] = false
            when /^--gui$/i
              @argv_options[:gui] = true
            when /^--game=(.+)$/i
              @argv_options[:game] = $1
            when /^--account=(.+)$/i
              @argv_options[:account] = $1
            when /^--password=(.+)$/i
              @argv_options[:password] = $1
            when /^--character=(.+)$/i
              @argv_options[:character] = $1
            when /^--frontend=(.+)$/i
              @argv_options[:frontend] = $1
            when /^--frontend-command=(.+)$/i
              @argv_options[:frontend_command] = $1
            when /^--save$/i
              @argv_options[:save] = true
            when /^--wine(?:\-prefix)?=.+$/i
              nil # already used when defining the Wine module
            when /\.sal$|Gse\.~xt$/i
              handle_sal_file(arg)
              bad_args.clear
            when /^--dark-mode=(true|false|on|off)$/i
              handle_dark_mode($1)
            else
              bad_args.push(arg)
            end
          end

          @argv_options
        end

        def self.handle_sal_file(arg)
          @argv_options[:sal] = arg
          unless File.exist?(@argv_options[:sal])
            @argv_options[:sal] = $1 if ARGV.join(' ') =~ /([A-Z]:\\.+?\.(?:sal|~xt))/i
          end
          unless File.exist?(@argv_options[:sal])
            @argv_options[:sal] = "#{Wine::PREFIX}/drive_c/#{@argv_options[:sal][3..-1].split('\\').join('/')}" if defined?(Wine)
          end
        end

        def self.handle_dark_mode(value)
          @argv_options[:dark_mode] = value =~ /^(true|on)$/i
          if defined?(Gtk)
            @theme_state = Lich.track_dark_mode = @argv_options[:dark_mode]
            Gtk::Settings.default.gtk_application_prefer_dark_theme = true if @theme_state == true
          end
        end

        def self.print_help
          puts 'Usage:  lich [OPTION]'
          puts 'General Options:'
          puts '  -h,   --help            Display this list.'
          puts '  -v,   --version         Display the program version number and credits.'
          puts '  -d,   --directory       Set the main Lich program directory.'
          puts '        --script-dir      Set the directory where Lich looks for scripts.'
          puts '        --data-dir        Set the directory where Lich will store script data.'
          puts '        --temp-dir        Set the directory where Lich will store temporary files.'
          puts '        --hosts-dir       Set the directory containing game server host definitions.'
          puts '        --hosts-file      Set the hosts file to use for host name resolution.'
          puts '  -w,   --wizard          Run in Wizard mode (default).'
          puts '  -s,   --stormfront      Run in StormFront mode.'
          puts '        --avalon          Run in Avalon mode.'
          puts '        --frostbite       Run in Frostbite mode.'
          puts '        --gui             Enable GUI (default).'
          puts '        --no-gui          Run without GUI (headless mode).'
          puts '        --dark-mode       Enable/disable dark mode (true|false|on|off). See example below.'
          puts '        --gemstone        Connect to the Gemstone IV Prime server (default).'
          puts '        --shattered       Connect to the Gemstone IV Shattered server.'
          puts '        --dragonrealms    Connect to the DragonRealms server.'
          puts '        --fallen          Connect to the DragonRealms Fallen server.'
          puts '        --platinum        Connect to the Gemstone IV/DragonRealms Platinum server.'
          puts '        --test            Connect to the test instance of the selected game server.'
          puts '  -g,   --game            Set the IP address and port of the game. See example below.'
          puts ''
          puts 'Login and Connection Options:'
          puts '        --login           Login with the specified character name.'
          puts '        --without-frontend Run without a frontend (headless mode).'
          puts '        --detachable-client Enable detachable client mode on specified port or host:port.'
          puts '        --reconnect       Automatically reconnect if connection is lost.'
          puts '        --reconnect-delay Set delay (in seconds) before attempting reconnection.'
          puts '        --start-scripts   Specify scripts to start after successful login.'
          puts '        --save            Save login credentials after successful login.'
          puts ''
          puts 'Account and Password Options:'
          puts '        --account         Specify game account name.'
          puts '        --password        Specify game account password.'
          puts '        --frontend        Specify frontend type (wizard, stormfront, avalon, genie, frostbite).'
          puts ''
          puts 'Encryption Management Options:'
          puts '  -aa, --add-account    Add a new account with password. See example below.'
          puts '  -cap, --change-account-password'
          puts '                        Change password for specified account. See example below.'
          puts '  -cmp, --change-master-password'
          puts '                        Change the master password for Enhanced encryption mode.'
          puts '  -rmp, --recover-master-password'
          puts '                        Recover a lost master password (requires backup recovery).'
          puts '        --convert-entries Convert existing account entries to specified encryption mode.'
          puts '                        Usage: --convert-entries [plaintext|standard|enhanced]'
          puts '  -cem, --change-encryption-mode'
          puts '                        Change the global encryption mode for all accounts.'
          puts '  -mp, --master-password'
          puts '                        Specify master password for Enhanced mode operations.'
          puts ''
          puts 'Legacy Installation Options:'
          puts '       --install         Configure Windows/WINE registry for SGE integration.'
          puts '       --uninstall       Remove Lich from registry.'
          puts '       --link-to-sge     Link Lich to Simutronics Game Entry.'
          puts '       --unlink-from-sge Unlink Lich from Simutronics Game Entry.'
          puts '       --link-to-sal     Link Lich to SAL (Simutronics Account Launcher).'
          puts '       --unlink-from-sal Unlink Lich from SAL.'
          puts ''
          puts 'Examples:'
          puts '  lich -w -d /usr/bin/lich/'
          puts '       ... (run Lich in Wizard mode using the dir \'/usr/bin/lich/\' as the program\'s home)'
          puts '  lich -g gs3.simutronics.net:4000'
          puts '       ... (run Lich using the IP address \'gs3.simutronics.net\' and the port number \'4000\')'
          puts '  lich --dragonrealms --test --genie'
          puts '       ... (run Lich connected to DragonRealms Test server for the Genie frontend)'
          puts '  lich --script-dir /mydir/scripts'
          puts '       ... (run Lich with its script directory set to \'/mydir/scripts\')'
          puts '  lich -aa MyAccount MyPassword --frontend stormfront'
          puts '       ... (add a new account with StormFront frontend)'
          puts '  lich -cap MyAccount NewPassword'
          puts '       ... (change password for MyAccount to NewPassword)'
          puts '  lich --convert-entries enhanced'
          puts '       ... (convert all saved entries to Enhanced encryption mode with master password)'
          puts '  lich --login MyCharName --no-gui --detachable-client=8000 --dark-mode=true'
          puts '       ... (login without GUI in headless mode with detachable client on port 8000)'
        end

        def self.print_version
          puts "The Lich, version #{LICH_VERSION}"
          puts ' (an implementation of the Ruby interpreter by Yukihiro Matsumoto designed to be a \'script engine\' for text-based MUDs)'
          puts ''
          puts '- The Lich program and all material collectively referred to as "The Lich project" is copyright (C) 2005-2006 Murray Miron.'
          puts '- The Gemstone IV and DragonRealms games are copyright (C) Simutronics Corporation.'
          puts '- The Wizard front-end and the StormFront front-end are also copyrighted by the Simutronics Corporation.'
          puts '- Ruby is (C) Yukihiro \'Matz\' Matsumoto.'
          puts ''
          puts 'Thanks to all those who\'ve reported bugs and helped me track down problems on both Windows and Linux.'
        end
      end

      # Apply side effects: dark mode, hosts-dir, detachable-client
      module SideEffects
        def self.execute(argv_options)
          handle_hosts_dir(argv_options)
          handle_detachable_client
          handle_sal_launch(argv_options)
        end

        def self.handle_hosts_dir(argv_options)
          if (arg = ARGV.find { |a| a == '--hosts-dir' })
            i = ARGV.index(arg)
            ARGV.delete_at(i)
            hosts_dir = ARGV[i]
            ARGV.delete_at(i)
            if hosts_dir && File.exist?(hosts_dir)
              hosts_dir = hosts_dir.tr('\\', '/')
              hosts_dir += '/' unless hosts_dir[-1..-1] == '/'
              argv_options[:hosts_dir] = hosts_dir
            else
              $stdout.puts "warning: given hosts directory does not exist: #{hosts_dir}"
            end
          end
        end

        def self.handle_detachable_client
          @detachable_client_host = '127.0.0.1'
          @detachable_client_port = nil
          if (arg = ARGV.find { |a| a =~ /^\-\-detachable\-client=[0-9]+$/ })
            @detachable_client_port = /^\-\-detachable\-client=([0-9]+)$/.match(arg).captures.first
          elsif (arg = ARGV.find { |a| a =~ /^\-\-detachable\-client=((?:\d{1,3}\.){3}\d{1,3}):([0-9]{1,5})$/ })
            @detachable_client_host, @detachable_client_port = /^\-\-detachable\-client=((?:\d{1,3}\.){3}\d{1,3}):([0-9]{1,5})$/.match(arg).captures
          end
        end

        def self.handle_sal_launch(argv_options)
          return unless argv_options[:sal]

          unless File.exist?(argv_options[:sal])
            Lich.log "error: launch file does not exist: #{argv_options[:sal]}"
            Lich.msgbox "error: launch file does not exist: #{argv_options[:sal]}"
            exit
          end
          Lich.log "info: launch file: #{argv_options[:sal]}"

          if argv_options[:sal] =~ /SGE\.sal/i
            unless (launcher_cmd = Lich.get_simu_launcher)
              $stdout.puts 'error: failed to find the Simutronics launcher'
              Lich.log 'error: failed to find the Simutronics launcher'
              exit
            end
            launcher_cmd.sub!('%1', argv_options[:sal])
            Lich.log "info: launcher_cmd: #{launcher_cmd}"
            if defined?(Win32) && launcher_cmd =~ /^"(.*?)"\s*(.*)$/
              dir_file = $1
              param = $2
              dir = dir_file.slice(/^.*[\\\/]/)
              file = dir_file.sub(/^.*[\\\/]/, '')
              operation = (Win32.isXP? ? 'open' : 'runas')
              Win32.ShellExecute(lpOperation: operation, lpFile: file, lpDirectory: dir, lpParameters: param)
              Lich.log "error: Win32.ShellExecute returned #{r}; Win32.GetLastError: #{Win32.GetLastError}" if r < 33
            elsif defined?(Wine)
              system("#{Wine::BIN} #{launcher_cmd}")
            else
              system(launcher_cmd)
            end
            exit
          end
        end
      end

      # Handle game connection configuration
      module GameConnection
        def self.execute
          if (arg = ARGV.find { |a| a == '-g' || a == '--game' })
            handle_explicit_game_connection(arg)
          elsif ARGV.include?('--gemstone')
            handle_gemstone_connection
          elsif ARGV.include?('--shattered')
            handle_shattered_connection
          elsif ARGV.include?('--fallen')
            handle_fallen_connection
          elsif ARGV.include?('--dragonrealms')
            handle_dragonrealms_connection
          else
            @game_host = nil
            @game_port = nil
            Lich.log 'info: no force-mode info given'
          end
        end

        def self.handle_explicit_game_connection(arg)
          @game_host, @game_port = ARGV[ARGV.index(arg) + 1].split(':')
          @game_port = @game_port.to_i
          $frontend = determine_frontend
        end

        def self.handle_gemstone_connection
          if ARGV.include?('--platinum')
            $platinum = true
            if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
              @game_host = 'storm.gs4.game.play.net'
              @game_port = 10124
              $frontend = 'stormfront'
            else
              @game_host = 'gs-plat.simutronics.net'
              @game_port = 10121
              $frontend = ARGV.any? { |a| a == '--avalon' } ? 'avalon' : 'wizard'
            end
          else
            $platinum = false
            if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
              @game_host = 'storm.gs4.game.play.net'
              @game_port = 10024
              $frontend = 'stormfront'
            else
              @game_host = 'gs3.simutronics.net'
              @game_port = 4900
              $frontend = ARGV.any? { |a| a == '--avalon' } ? 'avalon' : 'wizard'
            end
          end
        end

        def self.handle_shattered_connection
          $platinum = false
          if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
            @game_host = 'storm.gs4.game.play.net'
            @game_port = 10324
            $frontend = 'stormfront'
          else
            @game_host = 'gs4.simutronics.net'
            @game_port = 10321
            $frontend = ARGV.any? { |a| a == '--avalon' } ? 'avalon' : 'wizard'
          end
        end

        def self.handle_fallen_connection
          $platinum = false
          if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
            $frontend = 'stormfront'
            $stdout.puts 'fixme'
            Lich.log 'fixme'
            exit
          elsif ARGV.grep(/--genie/).any?
            @game_host = 'dr.simutronics.net'
            @game_port = 11324
            $frontend = 'genie'
          else
            $stdout.puts 'fixme'
            Lich.log 'fixme'
            exit
          end
        end

        def self.handle_dragonrealms_connection
          if ARGV.include?('--platinum')
            $platinum = true
            if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
              $frontend = 'stormfront'
              $stdout.puts 'fixme'
              Lich.log 'fixme'
              exit
            elsif ARGV.grep(/--genie/).any?
              @game_host = 'dr.simutronics.net'
              @game_port = 11124
              $frontend = 'genie'
            elsif ARGV.grep(/--frostbite/).any?
              @game_host = 'dr.simutronics.net'
              @game_port = 11124
              $frontend = 'frostbite'
            else
              $frontend = 'wizard'
              $stdout.puts 'fixme'
              Lich.log 'fixme'
              exit
            end
          else
            $platinum = false
            if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
              $frontend = 'stormfront'
              $stdout.puts 'fixme'
              Lich.log 'fixme'
              exit
            elsif ARGV.grep(/--genie/).any?
              @game_host = 'dr.simutronics.net'
              @game_port = ARGV.include?('--test') ? 11624 : 11024
              $frontend = 'genie'
            else
              @game_host = 'dr.simutronics.net'
              @game_port = ARGV.include?('--test') ? 11624 : 11024
              $frontend = ARGV.any? { |a| a == '--avalon' } ? 'avalon' : ARGV.any? { |a| a == '--frostbite' } ? 'frostbite' : 'wizard'
            end
          end
        end

        def self.determine_frontend
          if ARGV.any? { |a| a == '-s' || a == '--stormfront' }
            'stormfront'
          elsif ARGV.any? { |a| a == '-w' || a == '--wizard' }
            'wizard'
          elsif ARGV.any? { |a| a == '--avalon' }
            'avalon'
          elsif ARGV.any? { |a| a == '--frostbite' }
            'frostbite'
          else
            'unknown'
          end
        end
      end

      # Main orchestrator: Step 1-4 of ARGV processing
      def self.process_argv
        # Step 1: Clean launcher.exe
        ARGV.delete_if { |arg| arg =~ /launcher\.exe/i }

        # Step 2: Handle early-exit CLI operations (now in lib/common/cli/cli_orchestration.rb)
        Lich::Common::CLI::CLIOrchestration.execute

        # Step 3: Parse normal options and build @argv_options
        @argv_options = ArgvOptions::OptionParser.execute

        # Step 4: Apply side effects and handle special cases
        ArgvOptions::SideEffects.execute(@argv_options)

        # Step 5: Handle game connection configuration
        ArgvOptions::GameConnection.execute

        @argv_options
      end
    end
  end
end

# Execute ARGV processing
Lich::Main::ArgvOptions.process_argv
