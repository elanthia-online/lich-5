# Carve out from lich.rbw
# module Games on 2024-06-13

module Lich
  module Unknown
    module Game
    end
  end

  module Common
    # module Game
    # end
  end

  module Gemstone
    include Lich
    module Game
      @@socket    = nil
      @@mutex     = Mutex.new
      @@last_recv = nil
      @@thread    = nil
      @@buffer    = Lich::Common::SharedBuffer.new
      @@_buffer   = Lich::Common::SharedBuffer.new
      @@_buffer.max_size = 1000
      @@autostarted = false
      @@cli_scripts = false
      @@infomon_loaded = false
      @@room_number_after_ready = false
      @@last_id_shown_room_window = 0

      def self.clean_gs_serverstring(server_string)
        # The Rift, Scatter is broken...
        if server_string =~ /<compDef id='room text'><\/compDef>/
          server_string.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
        end
        return server_string
      end

      @atmospherics = false
      @combat_count = 0
      @end_combat_tags = ["<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow"]

      def self.clean_dr_serverstring(server_string)
        ## Clear out superfluous tags
        server_string = server_string.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />", "")
        server_string = server_string.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />", "")

        # DR occasionally has poor encoding in text, which causes parsing errors.
        # One example of this is in the discern text for the spell Membrach's Greed
        # which gets sent as Membrach\x92s Greed. This fixes the bad encoding until
        # Simu fixes it.
        if server_string =~ /\\x92/
          Lich.log "Detected poorly encoded apostrophe: #{server_string.inspect}"
          server_string.gsub!("\x92", "'")
          Lich.log "Changed poorly encoded apostrophe to: #{server_string.inspect}"
        end

        ## Fix combat wrapping components - Why, DR, Why?
        server_string = server_string.gsub("<pushStream id=\"combat\" /><component id=", "<component id=")

        # Fixes xml with \r\n in the middle of it like:
        # We close the first line and in the next segment, we remove the trailing bits
        # <component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n
        # <component id='room extra'>Placed around the interior, you see: some furniture and other bits of interest.\r\n
        # <component id='room exits'>Obvious paths: clockwise, widdershins.\r\n

        # Followed by in a closing line such as one of these:
        # </component>\r\n
        # <compass></compass></component>\r\n

        # If the pattern is on the left of the =~ the named capture gets assigned as a variable
        if /^<(?<xmltag>dynaStream|component) id='.*'>[^<]*(?!<\/\k<xmltag>>)\r\n$/ =~ server_string
          Lich.log "Open-ended #{xmltag} tag: #{server_string.inspect}"
          server_string.gsub!("\r\n", "</#{xmltag}>")
          Lich.log "Open-ended #{xmltag} tag tag fixed to: #{server_string.inspect}"
        end

        # Remove the now dangling closing tag
        if server_string =~ /^(?:(\"|<compass><\/compass>))?<\/(dynaStream|component)>\r\n/
          Lich.log "Extraneous closing tag detected and deleted: #{server_string.inspect}"
          server_string = ""
        end

        ## Fix duplicate pushStrings
        while server_string.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
          server_string = server_string.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />", "<pushStream id=\"combat\" />")
        end

        if @combat_count > 0
          @end_combat_tags.each do |tag|
            # server_string = "<!-- looking for tag: #{tag}" + server_string
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        @combat_count += server_string.scan("<pushStream id=\"combat\" />").length
        @combat_count -= server_string.scan("<popStream id=\"combat\" />").length
        @combat_count = 0 if @combat_count < 0

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

        return server_string
      end

      def Game.open(host, port)
        @@socket = TCPSocket.open(host, port)
        begin
          @@socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
        rescue
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue StandardError
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
        @@socket.sync = true

        # Add check to determine if the game server hung at initial response

        @@wrap_thread = Thread.new {
          @last_recv = Time.now
          while !@@autostarted && (Time.now - @last_recv < 6)
            break if @@autostarted
            sleep 0.2
          end

          puts 'look' if !@@autostarted
        }

        @@thread = Thread.new {
          begin
            while ($_SERVERSTRING_ = @@socket.gets)
              @@last_recv = Time.now
              @@_buffer.update($_SERVERSTRING_) if TESTING
              begin
                $cmd_prefix = String.new if $_SERVERSTRING_ =~ /^\034GSw/

                unless (XMLData.game.nil? or XMLData.game.empty?)
                  unless Module.const_defined?(:GameLoader)
                    require_relative 'common/game-loader'
                    GameLoader.load!
                  end
                end

                if XMLData.game =~ /^GS/
                  $_SERVERSTRING_ = self.clean_gs_serverstring($_SERVERSTRING_)
                else
                  $_SERVERSTRING_ = self.clean_dr_serverstring($_SERVERSTRING_)
                end

                pp $_SERVERSTRING_ if $deep_debug # retain for deep troubleshooting

                $_SERVERBUFFER_.push($_SERVERSTRING_)

                if !@@autostarted and $_SERVERSTRING_ =~ /<app char/
                  if Gem::Version.new(LICH_VERSION) > Gem::Version.new(Lich.core_updated_with_lich_version)
                    Lich::Messaging.mono(Lich::Messaging.monsterbold("New installation or updated version of Lich5 detected!"))
                    Lich::Messaging.mono(Lich::Messaging.monsterbold("Installing newest core scripts available to ensure you're up-to-date!"))
                    Lich::Messaging.mono("")
                    Lich::Util::Update.update_core_data_and_scripts
                  end
                  Script.start('autostart') if Script.exists?('autostart')
                  @@autostarted = true
                  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(RECOMMENDED_RUBY)
                    ruby_warning = Terminal::Table.new
                    ruby_warning.title = "Ruby Recommended Version Warning"
                    ruby_warning.add_row(["Please update your Ruby installation."])
                    ruby_warning.add_row(["You're currently running Ruby v#{Gem::Version.new(RUBY_VERSION)}!"])
                    ruby_warning.add_row(["It's recommended to run Ruby v#{Gem::Version.new(RECOMMENDED_RUBY)} or higher!"])
                    ruby_warning.add_row(["Future Lich5 releases will soon require this newer version."])
                    ruby_warning.add_row([" "])
                    ruby_warning.add_row(["Visit the following link for info on updating:"])
                    if XMLData.game =~ /^GS/
                      ruby_warning.add_row(["https://gswiki.play.net/Lich:Software/Installation"])
                    elsif XMLData.game =~ /^DR/
                      ruby_warning.add_row(["https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"])
                    else
                      ruby_warning.add_row(["Unknown game type #{XMLData.game} detected."])
                      ruby_warning.add_row(["Unsure of proper documentation, please seek assistance via discord!"])
                    end
                    ruby_warning.to_s.split("\n").each { |row|
                      Lich::Messaging.mono(Lich::Messaging.monsterbold(row))
                    }
                  end
                end

                if !@@infomon_loaded && (defined?(Infomon) || !$DRINFOMON_VERSION.nil?) && !XMLData.name.empty? && !XMLData.dialogs.empty?
                  ExecScript.start("Infomon.redo!", { :quiet => true, :name => "infomon_reset" }) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
                  @@infomon_loaded = true
                end

                if !@@cli_scripts && @@autostarted && !XMLData.name.empty?
                  if (arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ })
                    for script_name in arg.sub('--start-scripts=', '').split(',')
                      Script.start(script_name)
                    end
                  end
                  @@cli_scripts = true
                  Lich.log("info: logged in as #{XMLData.game}:#{XMLData.name}")
                end
                begin
                  # Check for valid XML prior to sending to client, corrects double and single nested quotes
                  REXML::Document.parse_stream("<root>#{$_SERVERSTRING_}</root>", XMLData)
                rescue
                  unless $!.to_s =~ /invalid byte sequence/
                    # Fixed invalid xml such as:
                    # <mode id="GAME"/><settingsInfo  space not found crc='0' instance='DR'/>
                    # <settingsInfo  space not found crc='0' instance='DR'/>
                    if $_SERVERSTRING_ =~ /<settingsInfo .*?space not found /
                      Lich.log "Invalid settingsInfo XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.sub!('space not found', '')
                      Lich.log "Invalid settingsInfo XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Illegal character "&" in raw string "  You also see a large bin labeled \"Lost & Found\", a hastily scrawled notice, a brightly painted sign, a silver bell, the Registrar's Office and "
                    if $_SERVERSTRING_ =~ /\&/
                      Lich.log "Invalid \& detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!("&", '&amp;')
                      Lich.log "Invalid \& stripped out: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Illegal character "\a" in raw string "\aYOU HAVE BEEN IDLE TOO LONG. PLEASE RESPOND.\a\n"
                    if $_SERVERSTRING_ =~ /\a/
                      Lich.log "Invalid \a detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!("\a", '')
                      Lich.log "Invalid \a stripped out: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Fixes invalid XML with nested single quotes in it such as:
                    # From DR intro tips
                    # <link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />
                    # From GS
                    # <d cmd='forage Imaera's Lace'>Imaera's Lace</d>, <d cmd='forage stalk burdock'>stalk of burdock</d>
                    while (data = $_SERVERSTRING_.match(/'([^=>]*'[^=>]*)'/))
                      Lich.log "Invalid nested single quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/'/, '&apos;'))
                      Lich.log "Invalid nested single quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Fixes invalid XML with nested double quotes in it such as:
                    # <subtitle=" - [Avlea's Bows, "The Straight and Arrow"]">
                    while (data = $_SERVERSTRING_.match(/"([^=]*"[^=]*)"/))
                      Lich.log "Invalid nested double quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/"/, '&quot;'))
                      Lich.log "Invalid nested double quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                    Lich.log "Invalid XML detected - please report this: #{$_SERVERSTRING_.inspect}"
                    Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                  end
                  XMLData.reset
                end
                unless $_SERVERSTRING_ =~ /^<settings /
                  if Module.const_defined?(:GameLoader)
                    infomon_serverstring = $_SERVERSTRING_.dup
                    if XMLData.game =~ /^GS/
                      Infomon::XMLParser.parse(infomon_serverstring)
                      stripped_infomon_serverstring = strip_xml(infomon_serverstring, type: 'infomon')
                      stripped_infomon_serverstring.split("\r\n").each { |line|
                        unless line.empty?
                          Infomon::Parser.parse(line)
                        end
                      }
                    elsif XMLData.game =~ /^DR/
                      DRParser.parse(infomon_serverstring)
                    end
                  end
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_, type: 'main')
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if defined?(Map) and Map.method_defined?(:last_seen_objects) and !Map.last_seen_objects and line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1 # DR only: copy loot line to Map.last_seen_objects
                    end

                    Script.new_downstream(line) if !line.empty?
                  }
                end
                if (alt_string = DownstreamHook.run($_SERVERSTRING_))
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if alt_string =~ /^(?:<resource picture="\d+"\/>|<popBold\/>)?<style id="roomName"\s+\/>/
                    if (Lich.display_lichid == true || Lich.display_uid == true)
                      if XMLData.game =~ /^GS/
                        if (Lich.display_lichid == true && Lich.display_uid == true)
                          alt_string.sub!(/] \(\d+\)/) { "]" }
                          alt_string.sub!(']') { " - #{Map.current.id}] (u#{(XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "nknown" : XMLData.room_id})" }
                        elsif Lich.display_lichid == true
                          alt_string.sub!(']') { " - #{Map.current.id}]" }
                        elsif Lich.display_uid == true
                          alt_string.sub!(/] \(\d+\)/) { "]" }
                          alt_string.sub!(']') { "] (u#{(XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "nknown" : XMLData.room_id})" }
                        end
                      end
                    end
                    @@room_number_after_ready = true
                  end
                  if $frontend =~ /genie/i && alt_string =~ /^<streamWindow id='room' title='Room' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
                    alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
                  end
                  if @@room_number_after_ready && alt_string =~ /<prompt /
                    if Lich.display_stringprocs == true
                      room_exits = []
                      Map.current.wayto.each do |key, value|
                        # Don't include cardinals / up/down/out (usually just climb/go)
                        if value.class == Proc
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
                        if value.class != Proc
                          room_exits << "<d cmd='#{value.dump[1..-2]}'>#{value.dump[1..-2]}</d>"
                        end
                      end
                      unless room_exits.empty?
                        alt_string = "Room Exits: #{room_exits.join(', ')}\r\n#{alt_string}"
                        if ['wrayth', 'stormfront'].include?($frontend) && Map.current.id != @@last_id_shown_room_window
                          alt_string = "#{alt_string}<pushStream id='room' ifClosedStyle='watching'/>Room Exits: #{room_exits.join(', ')}\r\n<popStream/>\r\n"
                          @@last_id_shown_room_window = Map.current.id
                        end
                      end
                    end
                    if XMLData.game =~ /^DR/
                      room_number = ""
                      room_number += "#{Map.current.id}" if Lich.display_lichid
                      room_number += " - " if Lich.display_lichid && Lich.display_uid
                      room_number += "#{XMLData.room_id}" if Lich.display_uid
                      unless room_number.empty?
                        alt_string = "Room Number: #{room_number}\r\n#{alt_string}"
                        if ['wrayth', 'stormfront'].include?($frontend)
                          alt_string = "<streamWindow id='main' title='Story' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop'/>\r\n#{alt_string}"
                          alt_string = "<streamWindow id='room' title='Room' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop' ifClosed='' resident='true'/>#{alt_string}"
                        end
                      end
                    end
                    @@room_number_after_ready = false
                  end
                  if $frontend =~ /^(?:wizard|avalon)$/
                    alt_string = sf_to_wiz(alt_string)
                  end
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
              rescue
                $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue StandardError
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          rescue
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace..slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          end
        }
        @@thread.priority = 4
        $_SERVER_ = @@socket # deprecated
      end

      def Game.thread
        @@thread
      end

      def Game.closed?
        if @@socket.nil?
          true
        else
          @@socket.closed?
        end
      end

      def Game.close
        if @@socket
          @@socket.close rescue nil
          @@thread.kill rescue nil
        end
      end

      def Game._puts(str)
        @@mutex.synchronize {
          @@socket.puts(str)
        }
      end

      def Game.puts(str)
        $_SCRIPTIDLETIMESTAMP_ = Time.now
        if (script = Script.current)
          script_name = script.name
        else
          script_name = '(unknown script)'
        end
        $_CLIENTBUFFER_.push "[#{script_name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"
        if script.nil? or not script.silent
          respond "[#{script_name}]#{$SEND_CHARACTER}#{str}\r\n"
        end
        Game._puts "#{$cmd_prefix}#{str}"
        $_LASTUPSTREAM_ = "[#{script_name}]#{$SEND_CHARACTER}#{str}"
      end

      def Game.gets
        @@buffer.gets
      end

      def Game.buffer
        @@buffer
      end

      def Game._gets
        @@_buffer.gets
      end

      def Game._buffer
        @@_buffer
      end
    end

    class Gift
      @@gift_start ||= Time.now
      @@pulse_count ||= 0
      def Gift.started
        @@gift_start = Time.now
        @@pulse_count = 0
      end

      def Gift.pulse
        @@pulse_count += 1
      end

      def Gift.remaining
        ([360 - @@pulse_count, 0].max * 60).to_f
      end

      def Gift.restarts_on
        @@gift_start + 594000
      end

      def Gift.serialize
        [@@gift_start, @@pulse_count]
      end

      def Gift.load_serialized=(array)
        @@gift_start = array[0]
        @@pulse_count = array[1].to_i
      end

      def Gift.ended
        @@pulse_count = 360
      end

      def Gift.stopwatch
        nil
      end
    end

    class Wounds
      def Wounds.leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end

      def Wounds.leye;      fix_injury_mode; XMLData.injuries['leftEye']['wound'];   end

      def Wounds.rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end

      def Wounds.reye;      fix_injury_mode; XMLData.injuries['rightEye']['wound'];  end

      def Wounds.head;      fix_injury_mode; XMLData.injuries['head']['wound'];      end

      def Wounds.neck;      fix_injury_mode; XMLData.injuries['neck']['wound'];      end

      def Wounds.back;      fix_injury_mode; XMLData.injuries['back']['wound'];      end

      def Wounds.chest;     fix_injury_mode; XMLData.injuries['chest']['wound'];     end

      def Wounds.abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end

      def Wounds.abs;       fix_injury_mode; XMLData.injuries['abdomen']['wound'];   end

      def Wounds.leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end

      def Wounds.larm;      fix_injury_mode; XMLData.injuries['leftArm']['wound'];   end

      def Wounds.rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end

      def Wounds.rarm;      fix_injury_mode; XMLData.injuries['rightArm']['wound'];  end

      def Wounds.rightHand; fix_injury_mode; XMLData.injuries['rightHand']['wound']; end

      def Wounds.rhand;     fix_injury_mode; XMLData.injuries['rightHand']['wound']; end

      def Wounds.leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end

      def Wounds.lhand;     fix_injury_mode; XMLData.injuries['leftHand']['wound'];  end

      def Wounds.leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end

      def Wounds.lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['wound'];   end

      def Wounds.rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end

      def Wounds.rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['wound'];  end

      def Wounds.leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['wound'];  end

      def Wounds.rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['wound']; end

      def Wounds.nsys;      fix_injury_mode; XMLData.injuries['nsys']['wound'];      end

      def Wounds.nerves;    fix_injury_mode; XMLData.injuries['nsys']['wound'];      end

      def Wounds.arms
        fix_injury_mode
        [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'], XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound']].max
      end

      def Wounds.limbs
        fix_injury_mode
        [XMLData.injuries['leftArm']['wound'], XMLData.injuries['rightArm']['wound'], XMLData.injuries['leftHand']['wound'], XMLData.injuries['rightHand']['wound'], XMLData.injuries['leftLeg']['wound'], XMLData.injuries['rightLeg']['wound']].max
      end

      def Wounds.torso
        fix_injury_mode
        [XMLData.injuries['rightEye']['wound'], XMLData.injuries['leftEye']['wound'], XMLData.injuries['chest']['wound'], XMLData.injuries['abdomen']['wound'], XMLData.injuries['back']['wound']].max
      end

      def Wounds.method_missing(_arg = nil)
        echo "Wounds: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"
        nil
      end
    end

    class Scars
      def Scars.leftEye;   fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end

      def Scars.leye;      fix_injury_mode; XMLData.injuries['leftEye']['scar'];   end

      def Scars.rightEye;  fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end

      def Scars.reye;      fix_injury_mode; XMLData.injuries['rightEye']['scar'];  end

      def Scars.head;      fix_injury_mode; XMLData.injuries['head']['scar'];      end

      def Scars.neck;      fix_injury_mode; XMLData.injuries['neck']['scar'];      end

      def Scars.back;      fix_injury_mode; XMLData.injuries['back']['scar'];      end

      def Scars.chest;     fix_injury_mode; XMLData.injuries['chest']['scar'];     end

      def Scars.abdomen;   fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end

      def Scars.abs;       fix_injury_mode; XMLData.injuries['abdomen']['scar'];   end

      def Scars.leftArm;   fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end

      def Scars.larm;      fix_injury_mode; XMLData.injuries['leftArm']['scar'];   end

      def Scars.rightArm;  fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end

      def Scars.rarm;      fix_injury_mode; XMLData.injuries['rightArm']['scar'];  end

      def Scars.rightHand; fix_injury_mode; XMLData.injuries['rightHand']['scar']; end

      def Scars.rhand;     fix_injury_mode; XMLData.injuries['rightHand']['scar']; end

      def Scars.leftHand;  fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end

      def Scars.lhand;     fix_injury_mode; XMLData.injuries['leftHand']['scar'];  end

      def Scars.leftLeg;   fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end

      def Scars.lleg;      fix_injury_mode; XMLData.injuries['leftLeg']['scar'];   end

      def Scars.rightLeg;  fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end

      def Scars.rleg;      fix_injury_mode; XMLData.injuries['rightLeg']['scar'];  end

      def Scars.leftFoot;  fix_injury_mode; XMLData.injuries['leftFoot']['scar'];  end

      def Scars.rightFoot; fix_injury_mode; XMLData.injuries['rightFoot']['scar']; end

      def Scars.nsys;      fix_injury_mode; XMLData.injuries['nsys']['scar'];      end

      def Scars.nerves;    fix_injury_mode; XMLData.injuries['nsys']['scar'];      end

      def Scars.arms
        fix_injury_mode
        [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'], XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar']].max
      end

      def Scars.limbs
        fix_injury_mode
        [XMLData.injuries['leftArm']['scar'], XMLData.injuries['rightArm']['scar'], XMLData.injuries['leftHand']['scar'], XMLData.injuries['rightHand']['scar'], XMLData.injuries['leftLeg']['scar'], XMLData.injuries['rightLeg']['scar']].max
      end

      def Scars.torso
        fix_injury_mode
        [XMLData.injuries['rightEye']['scar'], XMLData.injuries['leftEye']['scar'], XMLData.injuries['chest']['scar'], XMLData.injuries['abdomen']['scar'], XMLData.injuries['back']['scar']].max
      end

      def Scars.method_missing(_arg = nil)
        echo "Scars: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"
        nil
      end
    end
  end

  module DragonRealms
    include Lich
    module Game
      @@socket    = nil
      @@mutex     = Mutex.new
      @@last_recv = nil
      @@thread    = nil
      @@buffer    = Lich::Common::SharedBuffer.new
      @@_buffer   = Lich::Common::SharedBuffer.new
      @@_buffer.max_size = 1000
      @@autostarted = false
      @@cli_scripts = false
      @@infomon_loaded = false
      @@room_number_after_ready = false
      @@last_id_shown_room_window = 0

      def self.clean_gs_serverstring(server_string)
        # The Rift, Scatter is broken...
        if server_string =~ /<compDef id='room text'><\/compDef>/
          server_string.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
        end
        return server_string
      end

      @atmospherics = false
      @combat_count = 0
      @end_combat_tags = ["<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow"]

      def self.clean_dr_serverstring(server_string)
        ## Clear out superfluous tags
        server_string = server_string.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />", "")
        server_string = server_string.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />", "")

        # DR occasionally has poor encoding in text, which causes parsing errors.
        # One example of this is in the discern text for the spell Membrach's Greed
        # which gets sent as Membrach\x92s Greed. This fixes the bad encoding until
        # Simu fixes it.
        if server_string =~ /\\x92/
          Lich.log "Detected poorly encoded apostrophe: #{server_string.inspect}"
          server_string.gsub!("\x92", "'")
          Lich.log "Changed poorly encoded apostrophe to: #{server_string.inspect}"
        end

        ## Fix combat wrapping components - Why, DR, Why?
        server_string = server_string.gsub("<pushStream id=\"combat\" /><component id=", "<component id=")

        # Fixes xml with \r\n in the middle of it like:
        # We close the first line and in the next segment, we remove the trailing bits
        # <component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n
        # <component id='room extra'>Placed around the interior, you see: some furniture and other bits of interest.\r\n
        # <component id='room exits'>Obvious paths: clockwise, widdershins.\r\n

        # Followed by in a closing line such as one of these:
        # </component>\r\n
        # <compass></compass></component>\r\n

        # If the pattern is on the left of the =~ the named capture gets assigned as a variable
        if /^<(?<xmltag>dynaStream|component) id='.*'>[^<]*(?!<\/\k<xmltag>>)\r\n$/ =~ server_string
          Lich.log "Open-ended #{xmltag} tag: #{server_string.inspect}"
          server_string.gsub!("\r\n", "</#{xmltag}>")
          Lich.log "Open-ended #{xmltag} tag tag fixed to: #{server_string.inspect}"
        end

        # Remove the now dangling closing tag
        if server_string =~ /^(?:(\"|<compass><\/compass>))?<\/(dynaStream|component)>\r\n/
          Lich.log "Extraneous closing tag detected and deleted: #{server_string.inspect}"
          server_string = ""
        end

        ## Fix duplicate pushStrings
        while server_string.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
          server_string = server_string.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />", "<pushStream id=\"combat\" />")
        end

        if @combat_count > 0
          @end_combat_tags.each do |tag|
            # server_string = "<!-- looking for tag: #{tag}" + server_string
            if server_string.include?(tag)
              server_string = server_string.gsub(tag, "<popStream id=\"combat\" />" + tag) unless server_string.include?("<popStream id=\"combat\" />")
              @combat_count -= 1
            end
            if server_string.include?("<pushStream id=\"combat\" />")
              server_string = server_string.gsub("<pushStream id=\"combat\" />", "")
            end
          end
        end

        @combat_count += server_string.scan("<pushStream id=\"combat\" />").length
        @combat_count -= server_string.scan("<popStream id=\"combat\" />").length
        @combat_count = 0 if @combat_count < 0

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

        return server_string
      end

      def Game.open(host, port)
        @@socket = TCPSocket.open(host, port)
        begin
          @@socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
        rescue
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue StandardError
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
        @@socket.sync = true

        # Add check to determine if the game server hung at initial response

        @@wrap_thread = Thread.new {
          @last_recv = Time.now
          while !@@autostarted && (Time.now - @last_recv < 6)
            break if @@autostarted
            sleep 0.2
          end

          puts 'look' if !@@autostarted
        }

        @@thread = Thread.new {
          begin
            while ($_SERVERSTRING_ = @@socket.gets)
              @@last_recv = Time.now
              @@_buffer.update($_SERVERSTRING_) if TESTING
              begin
                $cmd_prefix = String.new if $_SERVERSTRING_ =~ /^\034GSw/

                unless (XMLData.game.nil? or XMLData.game.empty?)
                  unless Module.const_defined?(:GameLoader)
                    require_relative 'common/game-loader'
                    GameLoader.load!
                  end
                end

                if XMLData.game =~ /^GS/
                  $_SERVERSTRING_ = self.clean_gs_serverstring($_SERVERSTRING_)
                else
                  $_SERVERSTRING_ = self.clean_dr_serverstring($_SERVERSTRING_)
                end

                $_SERVERBUFFER_.push($_SERVERSTRING_)

                if !@@autostarted and $_SERVERSTRING_ =~ /<app char/
                  if Gem::Version.new(LICH_VERSION) > Gem::Version.new(Lich.core_updated_with_lich_version)
                    Lich::Messaging.mono(Lich::Messaging.monsterbold("New installation or updated version of Lich5 detected!"))
                    Lich::Messaging.mono(Lich::Messaging.monsterbold("Installing newest core scripts available to ensure you're up-to-date!"))
                    Lich::Messaging.mono("")
                    Lich::Util::Update.update_core_data_and_scripts
                  end
                  Script.start('autostart') if Script.exists?('autostart')
                  @@autostarted = true
                  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(RECOMMENDED_RUBY)
                    ruby_warning = Terminal::Table.new
                    ruby_warning.title = "Ruby Recommended Version Warning"
                    ruby_warning.add_row(["Please update your Ruby installation."])
                    ruby_warning.add_row(["You're currently running Ruby v#{Gem::Version.new(RUBY_VERSION)}!"])
                    ruby_warning.add_row(["It's recommended to run Ruby v#{Gem::Version.new(RECOMMENDED_RUBY)} or higher!"])
                    ruby_warning.add_row(["Future Lich5 releases will soon require this newer version."])
                    ruby_warning.add_row([" "])
                    ruby_warning.add_row(["Visit the following link for info on updating:"])
                    if XMLData.game =~ /^GS/
                      ruby_warning.add_row(["https://gswiki.play.net/Lich:Software/Installation"])
                    elsif XMLData.game =~ /^DR/
                      ruby_warning.add_row(["https://github.com/elanthia-online/lich-5/wiki/Documentation-for-Installing-and-Upgrading-Lich"])
                    else
                      ruby_warning.add_row(["Unknown game type #{XMLData.game} detected."])
                      ruby_warning.add_row(["Unsure of proper documentation, please seek assistance via discord!"])
                    end
                    ruby_warning.to_s.split("\n").each { |row|
                      Lich::Messaging.mono(Lich::Messaging.monsterbold(row))
                    }
                  end
                end

                if !@@infomon_loaded && (defined?(Infomon) || !$DRINFOMON_VERSION.nil?) && !XMLData.name.empty? && !XMLData.dialogs.empty?
                  ExecScript.start("Infomon.redo!", { :quiet => true, :name => "infomon_reset" }) if XMLData.game !~ /^DR/ && Infomon.db_refresh_needed?
                  @@infomon_loaded = true
                end

                if !@@cli_scripts && @@autostarted && !XMLData.name.empty?
                  if (arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ })
                    for script_name in arg.sub('--start-scripts=', '').split(',')
                      Script.start(script_name)
                    end
                  end
                  @@cli_scripts = true
                  Lich.log("info: logged in as #{XMLData.game}:#{XMLData.name}")
                end
                begin
                  # Check for valid XML prior to sending to client, corrects double and single nested quotes
                  REXML::Document.parse_stream("<root>#{$_SERVERSTRING_}</root>", XMLData)
                rescue
                  unless $!.to_s =~ /invalid byte sequence/
                    # Fixed invalid xml such as:
                    # <mode id="GAME"/><settingsInfo  space not found crc='0' instance='DR'/>
                    # <settingsInfo  space not found crc='0' instance='DR'/>
                    if $_SERVERSTRING_ =~ /<settingsInfo .*?space not found /
                      Lich.log "Invalid settingsInfo XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.sub!('space not found', '')
                      Lich.log "Invalid settingsInfo XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Illegal character "&" in raw string "  You also see a large bin labeled \"Lost & Found\", a hastily scrawled notice, a brightly painted sign, a silver bell, the Registrar's Office and "
                    if $_SERVERSTRING_ =~ /\&/
                      Lich.log "Invalid \& detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!("&", '&amp;')
                      Lich.log "Invalid \& stripped out: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Illegal character "\a" in raw string "\aYOU HAVE BEEN IDLE TOO LONG. PLEASE RESPOND.\a\n"
                    if $_SERVERSTRING_ =~ /\a/
                      Lich.log "Invalid \a detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!("\a", '')
                      Lich.log "Invalid \a stripped out: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Fixes invalid XML with nested single quotes in it such as:
                    # From DR intro tips
                    # <link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />
                    # From GS
                    # <d cmd='forage Imaera's Lace'>Imaera's Lace</d>, <d cmd='forage stalk burdock'>stalk of burdock</d>
                    while (data = $_SERVERSTRING_.match(/'([^=>]*'[^=>]*)'/))
                      Lich.log "Invalid nested single quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/'/, '&apos;'))
                      Lich.log "Invalid nested single quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    # Fixes invalid XML with nested double quotes in it such as:
                    # <subtitle=" - [Avlea's Bows, "The Straight and Arrow"]">
                    while (data = $_SERVERSTRING_.match(/"([^=]*"[^=]*)"/))
                      Lich.log "Invalid nested double quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                      $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/"/, '&quot;'))
                      Lich.log "Invalid nested double quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                      retry
                    end
                    $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                    Lich.log "Invalid XML detected - please report this: #{$_SERVERSTRING_.inspect}"
                    Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                  end
                  XMLData.reset
                end
                unless $_SERVERSTRING_ =~ /^<settings /
                  if Module.const_defined?(:GameLoader)
                    infomon_serverstring = $_SERVERSTRING_.dup
                    if XMLData.game =~ /^GS/
                      Infomon::XMLParser.parse(infomon_serverstring)
                      stripped_infomon_serverstring = strip_xml(infomon_serverstring, type: 'infomon')
                      stripped_infomon_serverstring.split("\r\n").each { |line|
                        unless line.empty?
                          Infomon::Parser.parse(line)
                        end
                      }
                    elsif XMLData.game =~ /^DR/
                      DRParser.parse(infomon_serverstring)
                    end
                  end
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_, type: 'main')
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if defined?(Map) and Map.method_defined?(:last_seen_objects) and !Map.last_seen_objects and line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1 # DR only: copy loot line to Map.last_seen_objects
                    end

                    Script.new_downstream(line) if !line.empty?
                  }
                end
                if (alt_string = DownstreamHook.run($_SERVERSTRING_))
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if alt_string =~ /^(?:<resource picture="\d+"\/>|<popBold\/>)?<style id="roomName"\s+\/>/
                    if (Lich.display_lichid == true || Lich.display_uid == true)
                      if XMLData.game =~ /^GS/
                        if (Lich.display_lichid == true && Lich.display_uid == true)
                          alt_string.sub!(/] \(\d+\)/) { "]" }
                          alt_string.sub!(']') { " - #{Map.current.id}] (u#{(XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "nknown" : XMLData.room_id})" }
                        elsif Lich.display_lichid == true
                          alt_string.sub!(']') { " - #{Map.current.id}]" }
                        elsif Lich.display_uid == true
                          alt_string.sub!(/] \(\d+\)/) { "]" }
                          alt_string.sub!(']') { "] (u#{(XMLData.room_id == 0 || XMLData.room_id > 4294967296) ? "nknown" : XMLData.room_id})" }
                        end
                      end
                    end
                    @@room_number_after_ready = true
                  end
                  if $frontend =~ /genie/i && alt_string =~ /^<streamWindow id='room' title='Room' subtitle=" - \[.*\] \((?:\d+|\*\*)\)"/
                    alt_string.sub!(/] \((?:\d+|\*\*)\)/) { "]" }
                  end
                  if @@room_number_after_ready && alt_string =~ /<prompt /
                    if Lich.display_stringprocs == true
                      room_exits = []
                      Map.current.wayto.each do |key, value|
                        # Don't include cardinals / up/down/out (usually just climb/go)
                        if value.class == Proc
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
                        if value.class != Proc
                          room_exits << "<d cmd='#{value.dump[1..-2]}'>#{value.dump[1..-2]}</d>"
                        end
                      end
                      unless room_exits.empty?
                        alt_string = "Room Exits: #{room_exits.join(', ')}\r\n#{alt_string}"
                        if ['wrayth', 'stormfront'].include?($frontend) && Map.current.id != @@last_id_shown_room_window
                          alt_string = "#{alt_string}<pushStream id='room' ifClosedStyle='watching'/>Room Exits: #{room_exits.join(', ')}\r\n<popStream/>\r\n"
                          @@last_id_shown_room_window = Map.current.id
                        end
                      end
                    end
                    if XMLData.game =~ /^DR/
                      room_number = ""
                      room_number += "#{Map.current.id}" if Lich.display_lichid
                      room_number += " - " if Lich.display_lichid && Lich.display_uid
                      room_number += "#{XMLData.room_id}" if Lich.display_uid
                      unless room_number.empty?
                        alt_string = "Room Number: #{room_number}\r\n#{alt_string}"
                        if ['wrayth', 'stormfront'].include?($frontend)
                          alt_string = "<streamWindow id='main' title='Story' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop'/>\r\n#{alt_string}"
                          alt_string = "<streamWindow id='room' title='Room' subtitle=\" - [#{XMLData.room_title[2..-3]} - #{room_number}]\" location='center' target='drop' ifClosed='' resident='true'/>#{alt_string}"
                        end
                      end
                    end
                    @@room_number_after_ready = false
                  end
                  if $frontend =~ /^(?:wizard|avalon)$/
                    alt_string = sf_to_wiz(alt_string)
                  end
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
              rescue
                $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue StandardError
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          rescue
            Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
            $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace..slice(0..10).join("\n\t")}"
            sleep 0.2
            retry unless $_CLIENT_.closed? or @@socket.closed? or ($!.to_s =~ /invalid argument|A connection attempt failed|An existing connection was forcibly closed|An established connection was aborted by the software in your host machine./i)
          end
        }
        @@thread.priority = 4
        $_SERVER_ = @@socket # deprecated
      end

      def Game.thread
        @@thread
      end

      def Game.closed?
        if @@socket.nil?
          true
        else
          @@socket.closed?
        end
      end

      def Game.close
        if @@socket
          @@socket.close rescue nil
          @@thread.kill rescue nil
        end
      end

      def Game._puts(str)
        @@mutex.synchronize {
          @@socket.puts(str)
        }
      end

      def Game.puts(str)
        $_SCRIPTIDLETIMESTAMP_ = Time.now
        if (script = Script.current)
          script_name = script.name
        else
          script_name = '(unknown script)'
        end
        $_CLIENTBUFFER_.push "[#{script_name}]#{$SEND_CHARACTER}#{$cmd_prefix}#{str}\r\n"
        if script.nil? or not script.silent
          respond "[#{script_name}]#{$SEND_CHARACTER}#{str}\r\n"
        end
        Game._puts "#{$cmd_prefix}#{str}"
        $_LASTUPSTREAM_ = "[#{script_name}]#{$SEND_CHARACTER}#{str}"
      end

      def Game.gets
        @@buffer.gets
      end

      def Game.buffer
        @@buffer
      end

      def Game._gets
        @@_buffer.gets
      end

      def Game._buffer
        @@_buffer
      end
    end
  end
end
