# frozen_string_literal: true

# Modernized version of games.rb with separated DR and GS functionality
# Original module carve out from lich.rbw
# Refactored on 2025-04-01

module Lich
  # Base module for game-specific functionality
  # Unknown game type module
  module Unknown
    module Game
      # Placeholder for unknown game types
    end
  end

  # Common module for shared functionality
  module Common
    # Placeholder for common game functionality
  end

  module GameBase
    # Factory for creating game-specific objects
    module GameInstanceFactory
      def self.create(game_type)
        case game_type
        when /^GS/
          Gemstone::GameInstance.new
        when /^DR/
          DragonRealms::GameInstance.new
        else
          # Default to a basic implementation if game type is unknown
          GameInstance::Base.new
        end
      end
    end

    # Game instance interface for game-specific behaviors
    module GameInstance
      # Base instance class that defines the interface
      class Base
        def initialize
          @atmospherics = false
          @combat_count = 0
          @end_combat_tags = ["<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow"]
        end

        def clean_serverstring(server_string)
          raise NotImplementedError, "#{self.class} must implement #clean_serverstring"
        end

        def handle_combat_tags(server_string)
          raise NotImplementedError, "#{self.class} must implement #handle_combat_tags"
        end

        def handle_atmospherics(server_string)
          raise NotImplementedError, "#{self.class} must implement #handle_atmospherics"
        end

        def get_documentation_url
          raise NotImplementedError, "#{self.class} must implement #get_documentation_url"
        end

        def process_game_specific_data(server_string)
          raise NotImplementedError, "#{self.class} must implement #process_game_specific_data"
        end

        def modify_room_display(alt_string, uid_from_string, lichid_from_uid_string)
          raise NotImplementedError, "#{self.class} must implement #modify_room_display"
        end

        def process_room_display(alt_string)
          raise NotImplementedError, "#{self.class} must implement #process_room_display"
        end

        def combat_count
          @combat_count
        end

        def atmospherics
          @atmospherics
        end

        def atmospherics=(value)
          @atmospherics = value
        end

        protected

        def increment_combat_count(server_string)
          @combat_count += server_string.scan("<pushStream id=\"combat\" />").length
          @combat_count -= server_string.scan("<popStream id=\"combat\" />").length
          @combat_count = 0 if @combat_count < 0
        end
      end
    end

    # XML string cleaner module
    module XMLCleaner
      class << self
        def clean_nested_quotes(server_string)
          # Fix nested single quotes
          unless (matches = server_string.scan(/'([^=>]*'[^=>]*)'/)).empty?
            Lich.log "Invalid nested single quotes XML tags detected: #{server_string.inspect}"
            matches.flatten.each do |match|
              server_string.gsub!(match, match.gsub(/'/, '&apos;'))
            end
            Lich.log "Invalid nested single quotes XML tags fixed to: #{server_string.inspect}"
          end

          # Fix nested double quotes
          unless (matches = server_string.scan(/"([^=>]*"[^=>]*)"/)).empty?
            Lich.log "Invalid nested double quotes XML tags detected: #{server_string.inspect}"
            matches.flatten.each do |match|
              server_string.gsub!(match, match.gsub(/"/, '&quot;'))
            end
            Lich.log "Invalid nested double quotes XML tags fixed to: #{server_string.inspect}"
          end

          server_string
        end

        def fix_invalid_characters(server_string)
          # Fix ampersands
          if server_string.include?('&') && !server_string.include?('&amp;') && !server_string.include?('&gt;') && !server_string.include?('&lt;') && !server_string.include?('&apos;') && !server_string.include?('&quot;')
            Lich.log "Invalid & detected: #{server_string.inspect}"
            server_string.gsub!('&', '&amp;')
            Lich.log "Invalid & fixed to: #{server_string.inspect}"
          end

          # Fix bell character
          if server_string.include?("\a")
            Lich.log "Invalid \\a detected: #{server_string.inspect}"
            server_string.gsub!("\a", '')
            Lich.log "Invalid \\a stripped out: #{server_string.inspect}"
          end

          # Fix poorly encoded apostrophes
          if server_string =~ /\\x92/
            Lich.log "Detected poorly encoded apostrophe: #{server_string.inspect}"
            server_string.gsub!("\x92", "'")
            Lich.log "Changed poorly encoded apostrophe to: #{server_string.inspect}"
          end

          server_string
        end

        def fix_xml_tags(server_string)
          # Fix open-ended XML tags
          if /^<(?<xmltag>dynaStream|component) id='.*'>[^<]*(?!<\/\k<xmltag>>)\r\n$/ =~ server_string
            Lich.log "Open-ended #{xmltag} tag: #{server_string.inspect}"
            server_string.gsub!("\r\n", "</#{xmltag}>")
            Lich.log "Open-ended #{xmltag} tag fixed to: #{server_string.inspect}"
          end

          # Remove dangling closing tags
          if server_string =~ /^(?:(\"|<compass><\/compass>))?<\/(dynaStream|component)>\r\n/
            Lich.log "Extraneous closing tag detected and deleted: #{server_string.inspect}"
            server_string = ""
          end

          # Remove unclosed tag in long strings from empath appraisals
          if server_string =~ / and <d cmd=\"transfer .+? nerves\">a/
            Lich.log "Unclosed wound (nerves) tag detected and deleted: #{server_string.inspect}"
            server_string.sub!(/ and <d cmd=\"transfer .+? nerves\">a.+?$/, " and more.")
          end

          server_string
        end
      end
    end

    # Base Game class with common functionality
    class Game
      class << self
        attr_reader :thread, :buffer, :_buffer, :game_instance

        def initialize_buffers
          @socket = nil
          @mutex = Mutex.new
          @last_recv = nil
          @thread = nil
          @buffer = Lich::Common::SharedBuffer.new
          @_buffer = Lich::Common::SharedBuffer.new
          @_buffer.max_size = 1000
          @autostarted = false
          @cli_scripts = false
          @infomon_loaded = false
          @room_number_after_ready = false
          @last_id_shown_room_window = 0
          @game_instance = nil
        end

        def set_game_instance(game_type)
          @game_instance = GameInstanceFactory.create(game_type)
        end

        def open(host, port)
          @socket = TCPSocket.open(host, port)
          begin
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
          rescue StandardError => e
            log_error("Socket option error", e)
          end
          @socket.sync = true

          start_wrap_thread
          start_main_thread

          @socket
        end

        def start_wrap_thread
          @wrap_thread = Thread.new do
            @last_recv = Time.now
            until @autostarted || (Time.now - @last_recv >= 6)
              break if @autostarted
              sleep 0.2
            end

            puts 'look' unless @autostarted
          end
        end

        def closed?
          @socket.nil? || @socket.closed?
        end

        def close
          if @socket
            @socket.close rescue nil
            @thread.kill rescue nil
          end
        end

        def _puts(str)
          @mutex.synchronize do
            @socket.puts(str)
          end
        end

        def puts(str)
          script_name = Script.current&.name || '(unknown script)'
          $_CLIENTBUFFER_.push "[#{script_name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"

          unless Script.current&.silent
            respond "[#{script_name}]#{$SEND_CHARACTER}#{str}\r\n"
          end

          _puts "#{$cmd_prefix}#{str}"
          $_LASTUPSTREAM_ = "[#{script_name}]#{$SEND_CHARACTER}#{str}"
        end

        def gets
          @buffer.gets
        end

        def _gets
          @_buffer.gets
        end

        def start_main_thread
          @thread = Thread.new do
            begin
              while (server_string = @socket.gets)
                @last_recv = Time.now
                @_buffer.update(server_string) if defined?(TESTING) && TESTING

                begin
                  process_server_string(server_string)
                rescue StandardError => e
                  log_error("Error processing server string", e)
                end
              end
            rescue StandardError => e
              handle_thread_error(e)
            end
          end
          @thread.priority = 4
        end

        def process_server_string(server_string)
          $cmd_prefix = String.new if server_string =~ /^\034GSw/

          # Load game-specific modules if needed
          unless (XMLData.game.nil? || XMLData.game.empty?)
            unless Module.const_defined?(:GameLoader)
              require_relative 'common/game-loader'
              GameLoader.load!
            end
          end

          # Set instance if not already set
          if @game_instance.nil? && !XMLData.game.nil? && !XMLData.game.empty?
            set_game_instance(XMLData.game)
          end

          # Clean server string based on game type
          if @game_instance
            server_string = @game_instance.clean_serverstring(server_string)
          end

          # Debug output if needed
          pp server_string if defined?($deep_debug) && $deep_debug

          # Push to server buffer
          $_SERVERBUFFER_.push(server_string)

          # Handle autostart
          handle_autostart if !@autostarted && server_string =~ /<app char/

          # Handle infomon loading
          if !@infomon_loaded && (defined?(Infomon) || !$DRINFOMON_VERSION.nil?) && !XMLData.name.nil? && !XMLData.name.empty? && !XMLData.dialogs.empty?
            ExecScript.start("Infomon.redo!", { quiet: true, name: "infomon_reset" }) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
            @infomon_loaded = true
          end

          # Handle CLI scripts
          if !@cli_scripts && @autostarted && !XMLData.name.nil? && !XMLData.name.empty?
            start_cli_scripts
          end

          # Process XML data
          process_xml_data(server_string) unless server_string =~ /^<settings /

          # Run downstream hooks
          process_downstream_hooks(server_string)
        end

        def handle_autostart
          if defined?(LICH_VERSION) && defined?(Lich.core_updated_with_lich_version) &&
             Gem::Version.new(LICH_VERSION) > Gem::Version.new(Lich.core_updated_with_lich_version)
            Lich::Messaging.mono(Lich::Messaging.monsterbold("New installation or updated version of Lich5 detected!"))
            Lich::Messaging.mono(Lich::Messaging.monsterbold("Installing newest core scripts available to ensure you're up-to-date!"))
            Lich::Messaging.mono("")
            Lich::Util::Update.update_core_data_and_scripts
          end

          Script.start('autostart') if defined?(Script) && Script.respond_to?(:exists?) && Script.exists?('autostart')
          @autostarted = true

          display_ruby_warning if defined?(RECOMMENDED_RUBY) && Gem::Version.new(RUBY_VERSION) < Gem::Version.new(RECOMMENDED_RUBY)
        end

        def display_ruby_warning
          ruby_warning = Terminal::Table.new
          ruby_warning.title = "Ruby Recommended Version Warning"
          ruby_warning.add_row(["Please update your Ruby installation."])
          ruby_warning.add_row(["You're currently running Ruby v#{Gem::Version.new(RUBY_VERSION)}!"])
          ruby_warning.add_row(["It's recommended to run Ruby v#{Gem::Version.new(RECOMMENDED_RUBY)} or higher!"])
          ruby_warning.add_row(["Future Lich5 releases will soon require this newer version."])
          ruby_warning.add_row([" "])
          ruby_warning.add_row(["Visit the following link for info on updating:"])

          # Use instance to get the appropriate documentation URL
          if @game_instance
            ruby_warning.add_row([@game_instance.get_documentation_url])
          else
            ruby_warning.add_row(["Unknown game type detected."])
            ruby_warning.add_row(["Unsure of proper documentation, please seek assistance via discord!"])
          end

          ruby_warning.to_s.split("\n").each do |row|
            Lich::Messaging.mono(Lich::Messaging.monsterbold(row))
          end
        end

        def start_cli_scripts
          if (arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ })
            arg.sub('--start-scripts=', '').split(',').each do |script_name|
              Script.start(script_name)
            end
          end
          @cli_scripts = true
          Lich.log("info: logged in as #{XMLData.game}:#{XMLData.name}")
        end

        def process_xml_data(server_string)
          begin
            # Check for valid XML
            REXML::Document.parse_stream("<root>#{server_string}</root>", XMLData)
          rescue => e
            case e.to_s
            # Missing attribute equal: <s> - in dynamic dialogs with a single apostrophe for possessive 'Tsetem's Items'
            when /nested single quotes|nested double quotes|Missing attribute equal: <\w+>/
              original_server_string = server_string.dup
              server_string = XMLCleaner.clean_nested_quotes(server_string)
              if original_server_string != server_string
                retry
              else
                handle_xml_error(server_string, e)
                XMLData.reset
                return
              end
            when /invalid characters/
              server_string = XMLCleaner.fix_invalid_characters(server_string)
              retry
            when /Missing end tag for 'd'/
              server_string = XMLCleaner.fix_xml_tags(server_string)
              retry
            else
              handle_xml_error(server_string, e)
              XMLData.reset
              return
            end
          end

          # Process game-specific data using instance
          if @game_instance && Module.const_defined?(:GameLoader)
            @game_instance.process_game_specific_data(server_string)
          end

          # Process downstream XML
          Script.new_downstream_xml(server_string) if defined?(Script)

          # Process stripped server string
          stripped_server = strip_xml(server_string, type: 'main')
          stripped_server.split("\r\n").each do |line|
            @buffer.update(line) if defined?(TESTING) && TESTING
            Script.new_downstream(line) if defined?(Script) && !line.empty?
          end
        end

        def handle_xml_error(server_string, error)
          # Ignoring certain XML errors
          unless error.to_s =~ /invalid byte sequence/
            # Handle specific XML errors
            if server_string =~ /<settingsInfo .*?space not found /
              Lich.log "Invalid settingsInfo XML tags detected: #{server_string.inspect}"
              server_string.sub!('space not found', '')
              Lich.log "Invalid settingsInfo XML tags fixed to: #{server_string.inspect}"
              return process_xml_data(server_string) # Return to retry with fixed string
            end

            $stdout.puts "error: server_thread: #{error}\n\t#{error.backtrace.join("\n\t")}"
            Lich.log "Invalid XML detected - please report this: #{server_string.inspect}"
            Lich.log "error: server_thread: #{error}\n\t#{error.backtrace.join("\n\t")}"
          end
        end

        def process_downstream_hooks(server_string)
          if (alt_string = DownstreamHook.run(server_string))
            process_room_information(alt_string)

            # Handle frontend-specific modifications
            if $frontend =~ /genie/i && alt_string =~ /^<streamWindow id='room' title='Room' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
              alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
            end

            if $frontend =~ /frostbite/i && alt_string =~ /^<streamWindow id='main' title='Story' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
              alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
            end

            # Handle room number display
            if @room_number_after_ready && alt_string =~ /<prompt /
              alt_string = @game_instance ? @game_instance.process_room_display(alt_string) : alt_string
              @room_number_after_ready = false
            end

            # Handle frontend-specific conversions
            if $frontend =~ /^(?:wizard|avalon)$/
              alt_string = sf_to_wiz(alt_string)
            end

            # Send to client
            send_to_client(alt_string)
          end
        end

        def process_room_information(alt_string)
          if alt_string =~ /^(<pushStream id="familiar" ifClosedStyle="watching"\/>)?(?:<resource picture="\d+"\/>|<popBold\/>)?<style id="roomName"\s+\/>/
            if (Lich.display_lichid == true || Lich.display_uid == true || Lich.hide_uid_flag == true)
              @game_instance ? @game_instance.modify_room_display(alt_string) : alt_string
            end
            @room_number_after_ready = true
            alt_string
          end
        end

        def send_to_client(alt_string)
          if $_DETACHABLE_CLIENT_
            begin
              $_DETACHABLE_CLIENT_.write(alt_string)
            rescue
              $_DETACHABLE_CLIENT_.close rescue nil
              $_DETACHABLE_CLIENT_ = nil
              respond "--- Lich: error: client_thread: #{$!}"
              respond $!.backtrace.first
              Lich.log "error: client_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            end
          else
            $_CLIENT_.write(alt_string)
          end
        end

        def handle_thread_error(error)
          Lich.log "error: server_thread: #{error}\n\t#{error.backtrace.join("\n\t")}"
          $stdout.puts "error: server_thread: #{error}\n\t#{error.backtrace.slice(0..10).join("\n\t")}"
          sleep 0.2
          # Cannot use retry here as it's not in a rescue block
          # Instead, we'll return a boolean indicating whether to retry
          return !($_CLIENT_.closed? || @socket.closed? || (error.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i))
        end

        protected

        def log_error(message, error)
          Lich.log "#{message}: #{error}\n\t#{error.backtrace.join("\n\t")}"
        end
      end
    end
  end

  # Gemstone game module
  module Gemstone
    include Lich

    # Base class for character status tracking
    class CharacterStatus
      class << self
        def fix_injury_mode(mode = 'both') # Default mode 'both' handles wounds (precedence) then scars
          case mode
          when 'scar', 'scars'
            unless XMLData.injury_mode == 1
              Game._puts '_injury 1'
              150.times { sleep 0.05; break if XMLData.injury_mode == 1 }
            end
          when 'wound', 'wounds' # future proof leaving in place, but this will likely not be used
            unless XMLData.injury_mode == 0
              Game._puts '_injury 0'
              150.times { sleep 0.05; break if XMLData.injury_mode == 0 }
            end
          when 'both'
            unless XMLData.injury_mode == 2
              Game._puts '_injury 2'
              150.times { sleep 0.05; break if XMLData.injury_mode == 2 }
            end
          else
            raise ArgumentError, "Invalid mode: #{mode}. Use 'scar', 'wound', or 'both'."
          end
        end

        def method_missing(_method_name = nil)
          result = Lich::Messaging.mono(Lich::Messaging.msg_format("bold", "#{self.name.split('::').last}: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"))
          # the _respond method used in Lich::Messaging returns nil upon success
          return result
        end
      end
    end

    # Gemstone-specific game instance
    class GameInstance < GameBase::GameInstance::Base
      def clean_serverstring(server_string)
        # The Rift, Scatter is broken...
        if server_string =~ /<compDef id='room text'><\/compDef>/
          server_string.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
        end

        # Handle combat and atmospherics
        server_string = handle_combat_tags(server_string)
        server_string = handle_atmospherics(server_string)

        server_string
      end

      def handle_combat_tags(server_string)
        if @combat_count > 0
          @end_combat_tags.each do |tag|
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        increment_combat_count(server_string)
        server_string
      end

      def handle_atmospherics(server_string)
        if @atmospherics
          @atmospherics = false
          server_string.prepend('<popStream id="atmospherics" />') unless server_string =~ /<popStream id="atmospherics" \/>/
        end

        if server_string =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
          server_string.sub!('<pushStream id="familiar" />', '')
        elsif server_string =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
          server_string.sub!('<pushStream id="atmospherics" />', '')
        elsif (server_string =~ /<pushStream id="atmospherics" \/>/)
          @atmospherics = true
        end

        server_string
      end

      def get_documentation_url
        "https://gswiki.play.net/Lich:Software/Installation"
      end

      def process_game_specific_data(server_string)
        infomon_serverstring = server_string.dup
        Infomon::XMLParser.parse(infomon_serverstring)
        stripped_infomon_serverstring = strip_xml(infomon_serverstring, type: 'infomon')
        stripped_infomon_serverstring.split("\r\n").each do |line|
          Infomon::Parser.parse(line) unless line.empty?
        end
      end

      def modify_room_display(alt_string)
        uid_from_string = alt_string.match(/] \((?<uid>\d+)\)/)
        if uid_from_string.nil?
          lichid_from_uid_string = Room.current.id
        else
          lichid_from_uid_string = Room["u#{uid_from_string[:uid]}"].id.to_i
        end
        if Lich.display_lichid == true
          alt_string.sub!(']') { " - #{lichid_from_uid_string}]" }
        end

        if Lich.display_uid == true
          alt_string.sub!(/] \(\d+\)/) { "]" }
          alt_string.sub!(']') { "] (#{(uid_from_string.nil? || XMLData.room_id == uid_from_string[:uid].to_i) ? ((XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "unknown" : "u#{XMLData.room_id}") : uid_from_string[:uid].to_i})" }
        end

        alt_string
      end

      def process_room_display(alt_string)
        if Lich.display_stringprocs == true
          room_exits = []
          Map.current.wayto.each do |key, value|
            # Don't include cardinals / up/down/out (usually just climb/go)
            if value.is_a?(StringProc)
              if Map.current.timeto[key].is_a?(Numeric) || (Map.current.timeto[key].is_a?(StringProc) && Map.current.timeto[key].call.is_a?(Numeric))
                room_exits << "<d cmd=';go2 #{key}'>#{Map[key].title.first.gsub(/\[|\]/, '')}#{Lich.display_lichid ? ('(' + Map[key].id.to_s + ')') : ''}</d>"
              end
            end
          end
          alt_string = "StringProcs: #{room_exits.join(', ')}\r\n#{alt_string}" unless room_exits.empty?
        end

        if Lich.display_exits == true
          room_exits = []
          Map.current.wayto.each do |_key, value|
            # Don't include cardinals / up/down/out (usually just climb/go)
            next if value.to_s =~ /^(?:o|d|u|n|ne|e|se|s|sw|w|nw|out|down|up|north|northeast|east|southeast|south|southwest|west|northwest)$/
            unless value.is_a?(StringProc)
              room_exits << "<d cmd='#{value.dump[1..-2]}'>#{value.dump[1..-2]}</d>"
            end
          end

          unless room_exits.empty?
            alt_string = "Room Exits: #{room_exits.join(', ')}\r\n#{alt_string}"
            if ['wrayth', 'stormfront'].include?($frontend) && Map.current.id != Game.instance_variable_get(:@last_id_shown_room_window)
              alt_string = "#{alt_string}<pushStream id='room' ifClosedStyle='watching'/>Room Exits: #{room_exits.join(', ')}\r\n<popStream/>\r\n"
              Game.instance_variable_set(:@last_id_shown_room_window, Map.current.id)
            end
          end
        end

        alt_string
      end
    end

    # Game class for Gemstone
    class Game < GameBase::Game
      class << self
        def initialize
          initialize_buffers
          set_game_instance('GS')
        end
      end

      # Initialize the class
      initialize
    end
  end

  # DragonRealms game module
  module DragonRealms
    include Lich

    # DragonRealms-specific game instance
    class GameInstance < GameBase::GameInstance::Base
      def clean_serverstring(server_string)
        # Clear out superfluous tags
        server_string = server_string.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />", "")
        server_string = server_string.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />", "")

        # Fix encoding issues
        server_string = GameBase::XMLCleaner.fix_invalid_characters(server_string)

        # Fix combat wrapping components
        server_string = server_string.gsub("<pushStream id=\"combat\" /><component id=", "<component id=")

        # Fix XML tags
        server_string = GameBase::XMLCleaner.fix_xml_tags(server_string)

        # Fix duplicate pushStrings
        while server_string.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
          server_string = server_string.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />", "<pushStream id=\"combat\" />")
        end

        # Handle combat and atmospherics
        server_string = handle_combat_tags(server_string)
        server_string = handle_atmospherics(server_string)

        server_string
      end

      def handle_combat_tags(server_string)
        if @combat_count > 0
          @end_combat_tags.each do |tag|
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        increment_combat_count(server_string)
        server_string
      end

      def handle_atmospherics(server_string)
        if @atmospherics
          @atmospherics = false
          server_string.prepend('<popStream id="atmospherics" />') unless server_string =~ /<popStream id="atmospherics" \/>/
        end

        if server_string =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
          server_string.sub!('<pushStream id="familiar" />', '')
        elsif server_string =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
          server_string.sub!('<pushStream id="atmospherics" />', '')
        elsif (server_string =~ /<pushStream id="atmospherics" \/>/)
          @atmospherics = true
        end

        server_string
      end

      def get_documentation_url
        "https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"
      end

      def process_game_specific_data(server_string)
        infomon_serverstring = server_string.dup
        DRParser.parse(infomon_serverstring)
      end

      def modify_room_display(alt_string)
        if Lich.display_uid == true
          alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
        elsif Lich.hide_uid_flag == true
          alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
        end

        alt_string
      end

      def process_room_display(alt_string)
        if Lich.display_stringprocs == true
          room_exits = []
          Map.current.wayto.each do |key, value|
            # Don't include cardinals / up/down/out (usually just climb/go)
            if value.is_a?(StringProc)
              if Map.current.timeto[key].is_a?(Numeric) || (Map.current.timeto[key].is_a?(StringProc) && Map.current.timeto[key].call.is_a?(Numeric))
                room_exits << "<d cmd=';go2 #{key}'>#{Map[key].title.first.gsub(/\[|\]/, '')}#{Lich.display_lichid ? ('(' + Map[key].id.to_s + ')') : ''}</d>"
              end
            end
          end
          alt_string = "StringProcs: #{room_exits.join(', ')}\r\n#{alt_string}" unless room_exits.empty?
        end

        if Lich.display_exits == true
          room_exits = []
          Map.current.wayto.each do |_key, value|
            # Don't include cardinals / up/down/out (usually just climb/go)
            next if value.to_s =~ /^(?:o|d|u|n|ne|e|se|s|sw|w|nw|out|down|up|north|northeast|east|southeast|south|southwest|west|northwest)$/
            unless value.is_a?(StringProc)
              room_exits << "<d cmd='#{value.dump[1..-2]}'>#{value.dump[1..-2]}</d>"
            end
          end

          unless room_exits.empty?
            alt_string = "Room Exits: #{room_exits.join(', ')}\r\n#{alt_string}"
          end
        end

        # DR-specific room number display
        room_number = ""
        room_number += "#{Map.current.id}" if Lich.display_lichid
        room_number += " - " if Lich.display_lichid && Lich.display_uid
        room_number += "(#{XMLData.room_id == 0 ? "**" : "u#{XMLData.room_id}"})" if Lich.display_uid

        unless room_number.empty?
          alt_string = "Room Number: #{room_number}\r\n#{alt_string}"
          if ['wrayth', 'stormfront'].include?($frontend)
            alt_string = "<streamWindow id='main' title='Story' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop'/>\r\n#{alt_string}"
            alt_string = "<streamWindow id='room' title='Room' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop' ifClosed='' resident='true'/>#{alt_string}"
          end
        end

        alt_string
      end
    end

    # Game class for DragonRealms
    class Game < GameBase::Game
      class << self
        def initialize
          initialize_buffers
          set_game_instance('DR')
        end
      end

      # Initialize the class
      initialize
    end
  end
end
