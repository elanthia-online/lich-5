module Games
  module Unknown
    module Game
    end
  end
  module Gemstone
    module Game
      @@socket    = nil
      @@mutex     = Mutex.new
      @@last_recv = nil
      @@thread    = nil
      @@buffer    = SharedBuffer.new
      @@_buffer   = SharedBuffer.new
      @@_buffer.max_size = 1000
      @@autostarted = false
      @@cli_scripts = false
      def Game.open(host, port)
        @@socket = TCPSocket.open(host, port)
        begin
          @@socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_KEEPALIVE, true)
        rescue
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        rescue Exception
          Lich.log "error: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
        end
        @@socket.sync = true

        @@thread = Thread.new {
          begin
            atmospherics = false
            combat_count = 0
            end_combat_tags = [ "<prompt", "<clearStream", "<component", "<pushStream id=\"percWindow" ]
            while $_SERVERSTRING_ = @@socket.gets
              @@last_recv = Time.now
              @@_buffer.update($_SERVERSTRING_) if TESTING
              begin
                $cmd_prefix = String.new if $_SERVERSTRING_ =~ /^\034GSw/
                ## Clear out superfluous tags
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><popStream id=\"combat\" />","")
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<popStream id=\"combat\" /><pushStream id=\"combat\" />","")

                ## Fix combat wrapping components - Why, DR, Why?
                $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><component id=","<component id=")
                # $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><prompt ","<prompt ")

                # Fixes xml with \r\n in the middle of it like:
                # <component id='room exits'>Obvious paths: clockwise, widdershins.\r\n
                # <compass></compass></component>\r\n
                # We close the first line and in the next segment, we remove the trailing bits
                # Because we can only match line by line, this couldn't be fixed in one matching block...
                if $_SERVERSTRING_ == "<component id='room exits'>Obvious paths: clockwise, widdershins.\r\n"
                  Lich.log "Unclosed component tag detected: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = "<component id='room exits'>Obvious paths: <d>clockwise</d>, <d>widdershins</d>.<compass></compass></component>"
                  Lich.log "Unclosed component tag fixed to: #{$_SERVERSTRING_.inspect}"
                  # retry
                end
                # This is an actual DR line "<compass></compass></component>\r\n" which happens when the above is sent... subbing it out since we fix the tag above.
                if $_SERVERSTRING_ == "<compass></compass></component>\r\n"
                  Lich.log "Extraneous closed tag detected: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = ""
                  Lich.log "Extraneous closed tag fixed: #{$_SERVERSTRING_.inspect}"
                end

                # "<component id='room objs'>  You also see a granite altar with several candles and a water jug on it, and a granite font.\r\n"
                # "<component id='room extra'>Placed around the interior, you see: some furniture and other bits of interest.\r\n
                # Followed by in a new line.
                # "</component>\r\n"
                if $_SERVERSTRING_ =~ /^<component id='room (?:objs|extra)'>[^<]*(?!<\/component>)\r\n/
                  Lich.log "Open-ended room objects component id tag: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_.gsub!("\r\n", "</component>")
                  Lich.log "Open-ended room objects component id tag fixed to: #{$_SERVERSTRING_.inspect}"
                end
                # "</component>\r\n"
                if $_SERVERSTRING_ == "</component>\r\n"
                  Lich.log "Extraneous closing tag detected and deleted: #{$_SERVERSTRING_.inspect}"
                  $_SERVERSTRING_ = ""
                end

                ## Fix duplicate pushStrings
                while $_SERVERSTRING_.include?("<pushStream id=\"combat\" /><pushStream id=\"combat\" />")
                  $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" /><pushStream id=\"combat\" />","<pushStream id=\"combat\" />")
                end

                if combat_count >0
                  end_combat_tags.each do | tag |
                    # $_SERVERSTRING_ = "<!-- looking for tag: #{tag}" + $_SERVERSTRING_
                    if $_SERVERSTRING_.include?(tag)
                      $_SERVERSTRING_ = $_SERVERSTRING_.gsub(tag,"<popStream id=\"combat\" />" + tag) unless $_SERVERSTRING_.include?("<popStream id=\"combat\" />")
                      combat_count -= 1
                    end
                    if $_SERVERSTRING_.include?("<pushStream id=\"combat\" />")
                      $_SERVERSTRING_ = $_SERVERSTRING_.gsub("<pushStream id=\"combat\" />","")
                    end
                  end
                end

                combat_count += $_SERVERSTRING_.scan("<pushStream id=\"combat\" />").length
                combat_count -= $_SERVERSTRING_.scan("<popStream id=\"combat\" />").length
                combat_count = 0 if combat_count < 0
                # The Rift, Scatter is broken...
                if $_SERVERSTRING_ =~ /<compDef id='room text'><\/compDef>/
                  $_SERVERSTRING_.sub!(/(.*)\s\s<compDef id='room text'><\/compDef>/) { "<compDef id='room desc'>#{$1}</compDef>" }
                end
                if atmospherics
                  atmospherics = false
                  $_SERVERSTRING.prepend('<popStream id="atmospherics" \/>') unless $_SERVERSTRING =~ /<popStream id="atmospherics" \/>/
                end
                if $_SERVERSTRING_ =~ /<pushStream id="familiar" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # Cry For Help spell is broken...
                  $_SERVERSTRING_.sub!('<pushStream id="familiar" />', '')
                elsif $_SERVERSTRING_ =~ /<pushStream id="atmospherics" \/><prompt time="[0-9]+">&gt;<\/prompt>/ # pet pigs in DragonRealms are broken...
                  $_SERVERSTRING_.sub!('<pushStream id="atmospherics" />', '')
                elsif ($_SERVERSTRING_ =~ /<pushStream id="atmospherics" \/>/)
                  atmospherics = true
                end
                #                        while $_SERVERSTRING_.scan('<pushStream').length > $_SERVERSTRING_.scan('<popStream').length
                #                           $_SERVERSTRING_.concat(@@socket.gets)
                #                        end
                $_SERVERBUFFER_.push($_SERVERSTRING_)

                if !@@autostarted and $_SERVERSTRING_ =~ /<app char/
                  require 'lib/map.rb'
                  Script.start('autostart') if Script.exists?('autostart')
                  @@autostarted = true
                end

                if @@autostarted and $_SERVERSTRING_ =~ /roomDesc/ and !@@cli_scripts
                  if arg = ARGV.find { |a| a =~ /^\-\-start\-scripts=/ }
                    for script_name in arg.sub('--start-scripts=', '').split(',')
                      Script.start(script_name)
                    end
                  end
                  @@cli_scripts = true
                end

                if alt_string = DownstreamHook.run($_SERVERSTRING_)
                  #                           Buffer.update(alt_string, Buffer::DOWNSTREAM_MOD)
                  if (Lich.display_lichid == true or Lich.display_uid == true) and XMLData.game =~ /^GS/ and alt_string =~ /<resource picture=.*roomName/
                    if (Lich.display_lichid == true and Lich.display_uid == true)
                      alt_string.sub!(']') {" - #{Map.current.id}] (u#{XMLData.room_id})"}
                    elsif Lich.display_lichid == true
                      alt_string.sub!(']') {" - #{Map.current.id}]"}
                    elsif Lich.display_uid == true
                      alt_string.sub!(']') {"] (u#{XMLData.room_id})"}
                    end
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
                unless $_SERVERSTRING_ =~ /^<settings /
                  # Fixed invalid xml such as:
                  # <mode id="GAME"/><settingsInfo  space not found crc='0' instance='DR'/>
                  # <settingsInfo  space not found crc='0' instance='DR'/>
                  if $_SERVERSTRING_ =~ /<settingsInfo .*?space not found /
                    Lich.log "Invalid settingsInfo XML tags detected: #{$_SERVERSTRING_.inspect}"
                    $_SERVERSTRING_.sub!('space not found', '')
                    Lich.log "Invalid settingsInfo XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                  end
                  begin
                    REXML::Document.parse_stream($_SERVERSTRING_, XMLData)
                    # XMLData.parse($_SERVERSTRING_)
                  rescue
                    unless $!.to_s =~ /invalid byte sequence/
                      # Fixes invalid XML with nested single quotes in it such as:
                      # From DR intro tips
                      # <link id='2' value='Ever wondered about the time you've spent in Elanthia?  Check the PLAYED verb!' cmd='played' echo='played' />
                      # From GS
                      # <d cmd='forage Imaera's Lace'>Imaera's Lace</d>, <d cmd='forage stalk burdock'>stalk of burdock</d>
                      while data = $_SERVERSTRING_.match(/'([^=>]*'[^=>]*)'/)
                        Lich.log "Invalid nested single quotes XML tags detected: #{$_SERVERSTRING_.inspect}"
                        $_SERVERSTRING_.gsub!(data[1], data[1].gsub!(/'/, '&apos;'))
                        Lich.log "Invalid nested single quotes XML tags fixed to: #{$_SERVERSTRING_.inspect}"
                        retry
                      end
                      # Fixes invalid XML with nested double quotes in it such as:
                      # <subtitle=" - [Avlea's Bows, "The Straight and Arrow"]">
                      while data = $_SERVERSTRING_.match(/"([^=]*"[^=]*)"/)
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
                  Script.new_downstream_xml($_SERVERSTRING_)
                  stripped_server = strip_xml($_SERVERSTRING_)
                  stripped_server.split("\r\n").each { |line|
                    @@buffer.update(line) if TESTING
                    if defined?(Map) and Map.method_defined?(:last_seen_objects) and !Map.last_seen_objects and line =~ /(You also see .*)$/
                      Map.last_seen_objects = $1  # DR only: copy loot line to Map.last_seen_objects
                    end
                    unless line =~ /^\s\*\s[A-Z][a-z]+ (?:returns home from a hard day of adventuring\.|joins the adventure\.|(?:is off to a rough start!  (?:H|She) )?just bit the dust!|was just incinerated!|was just vaporized!|has been vaporized!|has disconnected\.)$|^ \* The death cry of [A-Z][a-z]+ echoes in your mind!$|^\r*\n*$/
                      Script.new_downstream(line) unless line.empty?
                    end
                  }
                end
              rescue
                $stdout.puts "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
                Lich.log "error: server_thread: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
              end
            end
          rescue Exception
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
        if script = Script.current
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
    class Char
      @@name ||= nil
      @@citizenship ||= nil
      private_class_method :new
      def Char.init(blah)
        echo 'Char.init is no longer used.  Update or fix your script.'
      end

      def Char.name
        XMLData.name
      end

      def Char.name=(name)
        nil
      end

      def Char.health(*args)
        health(*args)
      end

      def Char.mana(*args)
        checkmana(*args)
      end

      def Char.spirit(*args)
        checkspirit(*args)
      end

      def Char.maxhealth
        Object.module_eval { maxhealth }
      end

      def Char.maxmana
        Object.module_eval { maxmana }
      end

      def Char.maxspirit
        Object.module_eval { maxspirit }
      end

      def Char.stamina(*args)
        checkstamina(*args)
      end

      def Char.maxstamina
        Object.module_eval { maxstamina }
      end

      def Char.cha(val = nil)
        nil
      end

      def Char.dump_info
        Marshal.dump([
                       Spell.detailed?,
                       Spell.serialize,
                       Spellsong.serialize,
                       Stats.serialize,
                       Skills.serialize,
                       Spells.serialize,
                       Gift.serialize,
                       Society.serialize,
                     ])
      end

      def Char.load_info(string)
        save = Char.dump_info
        begin
          Spell.load_detailed,
            Spell.load_active,
            Spellsong.load_serialized,
            Stats.load_serialized,
            Skills.load_serialized,
            Spells.load_serialized,
            Gift.load_serialized,
            Society.load_serialized = Marshal.load(string)
        rescue
          raise $! if string == save

          string = save
          retry
        end
      end

      def Char.method_missing(meth, *args)
        [Stats, Skills, Spellsong, Society].each { |klass|
          begin
            result = klass.__send__(meth, *args)
            return result
          rescue
          end
        }
        respond 'missing method: ' + meth
        raise NoMethodError
      end

      def Char.info
        ary = []
        ary.push sprintf("Name: %s  Race: %s  Profession: %s", XMLData.name, Stats.race, Stats.prof)
        ary.push sprintf("Gender: %s    Age: %d    Expr: %d    Level: %d", Stats.gender, Stats.age, Stats.exp, Stats.level)
        ary.push sprintf("%017.17s Normal (Bonus)  ...  Enhanced (Bonus)", "")
        %w[Strength Constitution Dexterity Agility Discipline Aura Logic Intuition Wisdom Influence].each { |stat|
          val, bon = Stats.send(stat[0..2].downcase)
          enh_val, enh_bon = Stats.send("enhanced_#{stat[0..2].downcase}")
          spc = " " * (4 - bon.to_s.length)
          ary.push sprintf("%012s (%s): %05s (%d) %s ... %05s (%d)", stat, stat[0..2].upcase, val, bon, spc, enh_val, enh_bon)
        }
        ary.push sprintf("Mana: %04s", mana)
        ary
      end

      def Char.skills
        ary = []
        ary.push sprintf("%s (at level %d), your current skill bonuses and ranks (including all modifiers) are:", XMLData.name, Stats.level)
        ary.push sprintf("  %-035s| Current Current", 'Skill Name')
        ary.push sprintf("  %-035s|%08s%08s", '', 'Bonus', 'Ranks')
        fmt = [['Two Weapon Combat', 'Armor Use', 'Shield Use', 'Combat Maneuvers', 'Edged Weapons', 'Blunt Weapons', 'Two-Handed Weapons', 'Ranged Weapons', 'Thrown Weapons', 'Polearm Weapons', 'Brawling', 'Ambush', 'Multi Opponent Combat', 'Combat Leadership', 'Physical Fitness', 'Dodging', 'Arcane Symbols', 'Magic Item Use', 'Spell Aiming', 'Harness Power', 'Elemental Mana Control', 'Mental Mana Control', 'Spirit Mana Control', 'Elemental Lore - Air', 'Elemental Lore - Earth', 'Elemental Lore - Fire', 'Elemental Lore - Water', 'Spiritual Lore - Blessings', 'Spiritual Lore - Religion', 'Spiritual Lore - Summoning', 'Sorcerous Lore - Demonology', 'Sorcerous Lore - Necromancy', 'Mental Lore - Divination', 'Mental Lore - Manipulation', 'Mental Lore - Telepathy', 'Mental Lore - Transference', 'Mental Lore - Transformation', 'Survival', 'Disarming Traps', 'Picking Locks', 'Stalking and Hiding', 'Perception', 'Climbing', 'Swimming', 'First Aid', 'Trading', 'Pickpocketing'], ['twoweaponcombat', 'armoruse', 'shielduse', 'combatmaneuvers', 'edgedweapons', 'bluntweapons', 'twohandedweapons', 'rangedweapons', 'thrownweapons', 'polearmweapons', 'brawling', 'ambush', 'multiopponentcombat', 'combatleadership', 'physicalfitness', 'dodging', 'arcanesymbols', 'magicitemuse', 'spellaiming', 'harnesspower', 'emc', 'mmc', 'smc', 'elair', 'elearth', 'elfire', 'elwater', 'slblessings', 'slreligion', 'slsummoning', 'sldemonology', 'slnecromancy', 'mldivination', 'mlmanipulation', 'mltelepathy', 'mltransference', 'mltransformation', 'survival', 'disarmingtraps', 'pickinglocks', 'stalkingandhiding', 'perception', 'climbing', 'swimming', 'firstaid', 'trading', 'pickpocketing']]
        0.upto(fmt.first.length - 1) { |n|
          dots = '.' * (35 - fmt[0][n].length)
          rnk = Skills.send(fmt[1][n])
          ary.push sprintf("  %s%s|%08s%08s", fmt[0][n], dots, Skills.to_bonus(rnk), rnk) unless rnk.zero?
        }
        %[Minor Elemental,Major Elemental,Minor Spirit,Major Spirit,Minor Mental,Bard,Cleric,Empath,Paladin,Ranger,Sorcerer,Wizard].split(',').each { |circ|
          rnk = Spells.send(circ.gsub(" ", '').downcase)
          if rnk.nonzero?
            ary.push ''
            ary.push "Spell Lists"
            dots = '.' * (35 - circ.length)
            ary.push sprintf("  %s%s|%016s", circ, dots, rnk)
          end
        }
        ary
      end

      def Char.citizenship
        @@citizenship
      end

      def Char.citizenship=(val)
        @@citizenship = val.to_s
      end
    end

    class Society
      @@status ||= String.new
      @@rank ||= 0
      def Society.serialize
        [@@status, @@rank]
      end

      def Society.load_serialized=(val)
        @@status, @@rank = val
      end

      def Society.status=(val)
        @@status = val
      end

      def Society.status
        @@status.dup
      end

      def Society.rank=(val)
        if val =~ /Master/
          if @@status =~ /Voln/
            @@rank = 26
          elsif @@status =~ /Council of Light|Guardians of Sunfist/
            @@rank = 20
          else
            @@rank = val.to_i
          end
        else
          @@rank = val.slice(/[0-9]+/).to_i
        end
      end

      def Society.step
        @@rank
      end

      def Society.member
        @@status.dup
      end

      def Society.rank
        @@rank
      end

      def Society.task
        XMLData.society_task
      end
    end

    class Spellsong
      @@renewed ||= Time.at(Time.now.to_i - 1200)
      def Spellsong.renewed
        @@renewed = Time.now
      end

      def Spellsong.renewed=(val)
        @@renewed = val
      end

      def Spellsong.renewed_at
        @@renewed
      end

      def Spellsong.timeleft
        (Spellsong.duration - ((Time.now - @@renewed) % Spellsong.duration)) / 60.to_f
      end

      def Spellsong.serialize
        Spellsong.timeleft
      end

      def Spellsong.load_serialized=(old)
        Thread.new {
          n = 0
          while Stats.level == 0
            sleep 0.25
            n += 1
            break if n >= 4
          end
          unless n >= 4
            @@renewed = Time.at(Time.now.to_f - (Spellsong.duration - old * 60.to_f))
          else
            @@renewed = Time.now
          end
        }
        nil
      end

      def Spellsong.duration
        total = 120
        1.upto(Stats.level.to_i) { |n|
          if n < 26
            total += 4
          elsif n < 51
            total += 3
          elsif n < 76
            total += 2
          else
            total += 1
          end
        }
        total + Stats.log[1].to_i + (Stats.inf[1].to_i * 3) + (Skills.mltelepathy.to_i * 2)
      end

      def Spellsong.renew_cost
        # fixme: multi-spell penalty?
        total = num_active = 0
        [1003, 1006, 1009, 1010, 1012, 1014, 1018, 1019, 1025].each { |song_num|
          if song = Spell[song_num]
            if song.active?
              total += song.renew_cost
              num_active += 1
            end
          else
            echo "Spellsong.renew_cost: warning: can't find song number #{song_num}"
          end
        }
        return total
      end

      def Spellsong.sonicarmordurability
        210 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.sonicbladedurability
        160 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.sonicweapondurability
        Spellsong.sonicbladedurability
      end

      def Spellsong.sonicshielddurability
        125 + (Stats.level / 2).round + Skills.to_bonus(Skills.elair)
      end

      def Spellsong.tonishastebonus
        bonus = -1
        thresholds = [30, 75]
        thresholds.each { |val| if Skills.elair >= val then bonus -= 1 end }
        bonus
      end

      def Spellsong.depressionpushdown
        20 + Skills.mltelepathy
      end

      def Spellsong.depressionslow
        thresholds = [10, 25, 45, 70, 100]
        bonus = -2
        thresholds.each { |val| if Skills.mltelepathy >= val then bonus -= 1 end }
        bonus
      end

      def Spellsong.holdingtargets
        1 + ((Spells.bard - 1) / 7).truncate
      end
    end

    class Skills
      @@twoweaponcombat ||= 0
      @@armoruse ||= 0
      @@shielduse ||= 0
      @@combatmaneuvers ||= 0
      @@edgedweapons ||= 0
      @@bluntweapons ||= 0
      @@twohandedweapons ||= 0
      @@rangedweapons ||= 0
      @@thrownweapons ||= 0
      @@polearmweapons ||= 0
      @@brawling ||= 0
      @@ambush ||= 0
      @@multiopponentcombat ||= 0
      @@combatleadership ||= 0
      @@physicalfitness ||= 0
      @@dodging ||= 0
      @@arcanesymbols ||= 0
      @@magicitemuse ||= 0
      @@spellaiming ||= 0
      @@harnesspower ||= 0
      @@emc ||= 0
      @@mmc ||= 0
      @@smc ||= 0
      @@elair ||= 0
      @@elearth ||= 0
      @@elfire ||= 0
      @@elwater ||= 0
      @@slblessings ||= 0
      @@slreligion ||= 0
      @@slsummoning ||= 0
      @@sldemonology ||= 0
      @@slnecromancy ||= 0
      @@mldivination ||= 0
      @@mlmanipulation ||= 0
      @@mltelepathy ||= 0
      @@mltransference ||= 0
      @@mltransformation ||= 0
      @@survival ||= 0
      @@disarmingtraps ||= 0
      @@pickinglocks ||= 0
      @@stalkingandhiding ||= 0
      @@perception ||= 0
      @@climbing ||= 0
      @@swimming ||= 0
      @@firstaid ||= 0
      @@trading ||= 0
      @@pickpocketing ||= 0

      def Skills.twoweaponcombat;           @@twoweaponcombat; end

      def Skills.twoweaponcombat=(val);     @@twoweaponcombat = val; end

      def Skills.armoruse;                  @@armoruse; end

      def Skills.armoruse=(val);            @@armoruse = val; end

      def Skills.shielduse;                 @@shielduse; end

      def Skills.shielduse=(val);           @@shielduse = val; end

      def Skills.combatmaneuvers;           @@combatmaneuvers; end

      def Skills.combatmaneuvers=(val);     @@combatmaneuvers = val; end

      def Skills.edgedweapons;              @@edgedweapons; end

      def Skills.edgedweapons=(val);        @@edgedweapons = val; end

      def Skills.bluntweapons;              @@bluntweapons; end

      def Skills.bluntweapons=(val);        @@bluntweapons = val; end

      def Skills.twohandedweapons;          @@twohandedweapons; end

      def Skills.twohandedweapons=(val);    @@twohandedweapons = val; end

      def Skills.rangedweapons;             @@rangedweapons; end

      def Skills.rangedweapons=(val);       @@rangedweapons = val; end

      def Skills.thrownweapons;             @@thrownweapons; end

      def Skills.thrownweapons=(val);       @@thrownweapons = val; end

      def Skills.polearmweapons;            @@polearmweapons; end

      def Skills.polearmweapons=(val);      @@polearmweapons = val; end

      def Skills.brawling;                  @@brawling; end

      def Skills.brawling=(val);            @@brawling = val; end

      def Skills.ambush;                    @@ambush; end

      def Skills.ambush=(val);              @@ambush = val; end

      def Skills.multiopponentcombat;       @@multiopponentcombat; end

      def Skills.multiopponentcombat=(val); @@multiopponentcombat = val; end

      def Skills.combatleadership;          @@combatleadership; end

      def Skills.combatleadership=(val);    @@combatleadership = val; end

      def Skills.physicalfitness;           @@physicalfitness; end

      def Skills.physicalfitness=(val);     @@physicalfitness = val; end

      def Skills.dodging;                   @@dodging; end

      def Skills.dodging=(val);             @@dodging = val; end

      def Skills.arcanesymbols;             @@arcanesymbols; end

      def Skills.arcanesymbols=(val);       @@arcanesymbols = val; end

      def Skills.magicitemuse;              @@magicitemuse; end

      def Skills.magicitemuse=(val);        @@magicitemuse = val; end

      def Skills.spellaiming;               @@spellaiming; end

      def Skills.spellaiming=(val);         @@spellaiming = val; end

      def Skills.harnesspower;              @@harnesspower; end

      def Skills.harnesspower=(val);        @@harnesspower = val; end

      def Skills.emc;                       @@emc; end

      def Skills.emc=(val);                 @@emc = val; end

      def Skills.mmc;                       @@mmc; end

      def Skills.mmc=(val);                 @@mmc = val; end

      def Skills.smc;                       @@smc; end

      def Skills.smc=(val);                 @@smc = val; end

      def Skills.elair;                     @@elair; end

      def Skills.elair=(val);               @@elair = val; end

      def Skills.elearth;                   @@elearth; end

      def Skills.elearth=(val);             @@elearth = val; end

      def Skills.elfire;                    @@elfire; end

      def Skills.elfire=(val);              @@elfire = val; end

      def Skills.elwater;                   @@elwater; end

      def Skills.elwater=(val);             @@elwater = val; end

      def Skills.slblessings;               @@slblessings; end

      def Skills.slblessings=(val);         @@slblessings = val; end

      def Skills.slreligion;                @@slreligion; end

      def Skills.slreligion=(val);          @@slreligion = val; end

      def Skills.slsummoning;               @@slsummoning; end

      def Skills.slsummoning=(val);         @@slsummoning = val; end

      def Skills.sldemonology;              @@sldemonology; end

      def Skills.sldemonology=(val);        @@sldemonology = val; end

      def Skills.slnecromancy;              @@slnecromancy; end

      def Skills.slnecromancy=(val);        @@slnecromancy = val; end

      def Skills.mldivination;              @@mldivination; end

      def Skills.mldivination=(val);        @@mldivination = val; end

      def Skills.mlmanipulation;            @@mlmanipulation; end

      def Skills.mlmanipulation=(val);      @@mlmanipulation = val; end

      def Skills.mltelepathy;               @@mltelepathy; end

      def Skills.mltelepathy=(val);         @@mltelepathy = val; end

      def Skills.mltransference;            @@mltransference; end

      def Skills.mltransference=(val);      @@mltransference = val; end

      def Skills.mltransformation;          @@mltransformation; end

      def Skills.mltransformation=(val);    @@mltransformation = val; end

      def Skills.survival;                  @@survival; end

      def Skills.survival=(val);            @@survival = val; end

      def Skills.disarmingtraps;            @@disarmingtraps; end

      def Skills.disarmingtraps=(val);      @@disarmingtraps = val; end

      def Skills.pickinglocks;              @@pickinglocks; end

      def Skills.pickinglocks=(val);        @@pickinglocks = val; end

      def Skills.stalkingandhiding;         @@stalkingandhiding; end

      def Skills.stalkingandhiding=(val);   @@stalkingandhiding = val; end

      def Skills.perception;                @@perception; end

      def Skills.perception=(val);          @@perception = val; end

      def Skills.climbing;                  @@climbing; end

      def Skills.climbing=(val);            @@climbing = val; end

      def Skills.swimming;                  @@swimming; end

      def Skills.swimming=(val);            @@swimming = val; end

      def Skills.firstaid;                  @@firstaid; end

      def Skills.firstaid=(val);            @@firstaid = val; end

      def Skills.trading;                   @@trading; end

      def Skills.trading=(val);             @@trading = val; end

      def Skills.pickpocketing;             @@pickpocketing; end

      def Skills.pickpocketing=(val);       @@pickpocketing = val; end

      def Skills.serialize
        [@@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing]
      end

      def Skills.load_serialized=(array)
        @@twoweaponcombat, @@armoruse, @@shielduse, @@combatmaneuvers, @@edgedweapons, @@bluntweapons, @@twohandedweapons, @@rangedweapons, @@thrownweapons, @@polearmweapons, @@brawling, @@ambush, @@multiopponentcombat, @@combatleadership, @@physicalfitness, @@dodging, @@arcanesymbols, @@magicitemuse, @@spellaiming, @@harnesspower, @@emc, @@mmc, @@smc, @@elair, @@elearth, @@elfire, @@elwater, @@slblessings, @@slreligion, @@slsummoning, @@sldemonology, @@slnecromancy, @@mldivination, @@mlmanipulation, @@mltelepathy, @@mltransference, @@mltransformation, @@survival, @@disarmingtraps, @@pickinglocks, @@stalkingandhiding, @@perception, @@climbing, @@swimming, @@firstaid, @@trading, @@pickpocketing = array
      end

      def Skills.to_bonus(ranks)
        bonus = 0
        while ranks > 0
          if ranks > 40
            bonus += (ranks - 40)
            ranks = 40
          elsif ranks > 30
            bonus += (ranks - 30) * 2
            ranks = 30
          elsif ranks > 20
            bonus += (ranks - 20) * 3
            ranks = 20
          elsif ranks > 10
            bonus += (ranks - 10) * 4
            ranks = 10
          else
            bonus += (ranks * 5)
            ranks = 0
          end
        end
        bonus
      end
    end

    class Spells
      @@minorelemental ||= 0
      @@minormental    ||= 0
      @@majorelemental ||= 0
      @@minorspiritual ||= 0
      @@majorspiritual ||= 0
      @@wizard         ||= 0
      @@sorcerer       ||= 0
      @@ranger         ||= 0
      @@paladin        ||= 0
      @@empath         ||= 0
      @@cleric         ||= 0
      @@bard           ||= 0
      def Spells.minorelemental=(val); @@minorelemental = val; end

      def Spells.minorelemental;       @@minorelemental;       end

      def Spells.minormental=(val);    @@minormental = val;    end

      def Spells.minormental;          @@minormental;          end

      def Spells.majorelemental=(val); @@majorelemental = val; end

      def Spells.majorelemental;       @@majorelemental;       end

      def Spells.minorspiritual=(val); @@minorspiritual = val; end

      def Spells.minorspiritual;       @@minorspiritual;       end

      def Spells.minorspirit=(val);    @@minorspiritual = val; end

      def Spells.minorspirit;          @@minorspiritual;       end

      def Spells.majorspiritual=(val); @@majorspiritual = val; end

      def Spells.majorspiritual;       @@majorspiritual;       end

      def Spells.majorspirit=(val);    @@majorspiritual = val; end

      def Spells.majorspirit;          @@majorspiritual;       end

      def Spells.wizard=(val);         @@wizard = val;         end

      def Spells.wizard;               @@wizard;               end

      def Spells.sorcerer=(val);       @@sorcerer = val;       end

      def Spells.sorcerer;             @@sorcerer;             end

      def Spells.ranger=(val);         @@ranger = val;         end

      def Spells.ranger;               @@ranger;               end

      def Spells.paladin=(val);        @@paladin = val;        end

      def Spells.paladin;              @@paladin;              end

      def Spells.empath=(val);         @@empath = val;         end

      def Spells.empath;               @@empath;               end

      def Spells.cleric=(val);         @@cleric = val;         end

      def Spells.cleric;               @@cleric;               end

      def Spells.bard=(val);           @@bard = val;           end

      def Spells.bard;                 @@bard;                 end

      def Spells.get_circle_name(num)
        val = num.to_s
        if val == '1'
          'Minor Spirit'
        elsif val == '2'
          'Major Spirit'
        elsif val == '3'
          'Cleric'
        elsif val == '4'
          'Minor Elemental'
        elsif val == '5'
          'Major Elemental'
        elsif val == '6'
          'Ranger'
        elsif val == '7'
          'Sorcerer'
        elsif val == '9'
          'Wizard'
        elsif val == '10'
          'Bard'
        elsif val == '11'
          'Empath'
        elsif val == '12'
          'Minor Mental'
        elsif val == '16'
          'Paladin'
        elsif val == '17'
          'Arcane'
        elsif val == '66'
          'Death'
        elsif val == '65'
          'Imbedded Enchantment'
        elsif val == '90'
          'Miscellaneous'
        elsif val == '95'
          'Armor Specialization'
        elsif val == '96'
          'Combat Maneuvers'
        elsif val == '97'
          'Guardians of Sunfist'
        elsif val == '98'
          'Order of Voln'
        elsif val == '99'
          'Council of Light'
        else
          'Unknown Circle'
        end
      end

      def Spells.active
        Spell.active
      end

      def Spells.known
        known_spells = Array.new
        Spell.list.each { |spell| known_spells.push(spell) if spell.known? }
        return known_spells
      end

      def Spells.serialize
        [@@minorelemental, @@majorelemental, @@minorspiritual, @@majorspiritual, @@wizard, @@sorcerer, @@ranger, @@paladin, @@empath, @@cleric, @@bard, @@minormental]
      end

      def Spells.load_serialized=(val)
        @@minorelemental, @@majorelemental, @@minorspiritual, @@majorspiritual, @@wizard, @@sorcerer, @@ranger, @@paladin, @@empath, @@cleric, @@bard, @@minormental = val
        # new spell circle added 2012-07-18; old data files will make @@minormental nil
        @@minormental ||= 0
      end
    end

    require_relative("./lib/spell.rb")

    # #updating PSM3 abilities via breakout - 20210801
    require_relative("./lib/armor.rb")
    require_relative("./lib/cman.rb")
    require_relative("./lib/feat.rb")
    require_relative("./lib/shield.rb")
    require_relative("./lib/weapon.rb")

    class Stats
      @@race ||= 'unknown'
      @@prof ||= 'unknown'
      @@gender ||= 'unknown'
      @@age ||= 0
      @@level ||= 0
      @@str ||= [0, 0]
      @@con ||= [0, 0]
      @@dex ||= [0, 0]
      @@agi ||= [0, 0]
      @@dis ||= [0, 0]
      @@aur ||= [0, 0]
      @@log ||= [0, 0]
      @@int ||= [0, 0]
      @@wis ||= [0, 0]
      @@inf ||= [0, 0]
      @@enhanced_str ||= [0, 0]
      @@enhanced_con ||= [0, 0]
      @@enhanced_dex ||= [0, 0]
      @@enhanced_agi ||= [0, 0]
      @@enhanced_dis ||= [0, 0]
      @@enhanced_aur ||= [0, 0]
      @@enhanced_log ||= [0, 0]
      @@enhanced_int ||= [0, 0]
      @@enhanced_wis ||= [0, 0]
      @@enhanced_inf ||= [0, 0]
      def Stats.race;         @@race; end

      def Stats.race=(val);   @@race = val; end

      def Stats.prof;         @@prof; end

      def Stats.prof=(val);   @@prof = val; end

      def Stats.gender;       @@gender; end

      def Stats.gender=(val); @@gender = val; end

      def Stats.age;          @@age; end

      def Stats.age=(val);    @@age = val; end

      def Stats.level;        @@level; end

      def Stats.level=(val);  @@level = val; end

      def Stats.str;          @@str; end

      def Stats.str=(val);    @@str = val; end

      def Stats.con;          @@con; end

      def Stats.con=(val);    @@con = val; end

      def Stats.dex;          @@dex; end

      def Stats.dex=(val);    @@dex = val; end

      def Stats.agi;          @@agi; end

      def Stats.agi=(val);    @@agi = val; end

      def Stats.dis;          @@dis; end

      def Stats.dis=(val);    @@dis = val; end

      def Stats.aur;          @@aur; end

      def Stats.aur=(val);    @@aur = val; end

      def Stats.log;          @@log; end

      def Stats.log=(val);    @@log = val; end

      def Stats.int;          @@int; end

      def Stats.int=(val);    @@int = val; end

      def Stats.wis;          @@wis; end

      def Stats.wis=(val);    @@wis = val; end

      def Stats.inf;          @@inf; end

      def Stats.inf=(val);    @@inf = val; end

      def Stats.enhanced_str;          @@enhanced_str; end

      def Stats.enhanced_str=(val);    @@enhanced_str = val; end

      def Stats.enhanced_con;          @@enhanced_con; end

      def Stats.enhanced_con=(val);    @@enhanced_con = val; end

      def Stats.enhanced_dex;          @@enhanced_dex; end

      def Stats.enhanced_dex=(val);    @@enhanced_dex = val; end

      def Stats.enhanced_agi;          @@enhanced_agi; end

      def Stats.enhanced_agi=(val);    @@enhanced_agi = val; end

      def Stats.enhanced_dis;          @@enhanced_dis; end

      def Stats.enhanced_dis=(val);    @@enhanced_dis = val; end

      def Stats.enhanced_aur;          @@enhanced_aur; end

      def Stats.enhanced_aur=(val);    @@enhanced_aur = val; end

      def Stats.enhanced_log;          @@enhanced_log; end

      def Stats.enhanced_log=(val);    @@enhanced_log = val; end

      def Stats.enhanced_int;          @@enhanced_int; end

      def Stats.enhanced_int=(val);    @@enhanced_int = val; end

      def Stats.enhanced_wis;          @@enhanced_wis; end

      def Stats.enhanced_wis=(val);    @@enhanced_wis = val; end

      def Stats.enhanced_inf;          @@enhanced_inf; end

      def Stats.enhanced_inf=(val);    @@enhanced_inf = val; end

      def Stats.exp
        if XMLData.next_level_text =~ /until next level/
          exp_threshold = [2500, 5000, 10000, 17500, 27500, 40000, 55000, 72500, 92500, 115000, 140000, 167000, 197500, 230000, 265000, 302000, 341000, 382000, 425000, 470000, 517000, 566000, 617000, 670000, 725000, 781500, 839500, 899000, 960000, 1022500, 1086500, 1152000, 1219000, 1287500, 1357500, 1429000, 1502000, 1576500, 1652500, 1730000, 1808500, 1888000, 1968500, 2050000, 2132500, 2216000, 2300500, 2386000, 2472500, 2560000, 2648000, 2736500, 2825500, 2915000, 3005000, 3095500, 3186500, 3278000, 3370000, 3462500, 3555500, 3649000, 3743000, 3837500, 3932500, 4028000, 4124000, 4220500, 4317500, 4415000, 4513000, 4611500, 4710500, 4810000, 4910000, 5010500, 5111500, 5213000, 5315000, 5417500, 5520500, 5624000, 5728000, 5832500, 5937500, 6043000, 6149000, 6255500, 6362500, 6470000, 6578000, 6686500, 6795500, 6905000, 7015000, 7125500, 7236500, 7348000, 7460000, 7572500]
          exp_threshold[XMLData.level] - XMLData.next_level_text.slice(/[0-9]+/).to_i
        else
          XMLData.next_level_text.slice(/[0-9]+/).to_i
        end
      end

      def Stats.exp=(val); nil; end

      def Stats.serialize
        [@@race, @@prof, @@gender, @@age, Stats.exp, @@level, @@str, @@con, @@dex, @@agi, @@dis, @@aur, @@log, @@int, @@wis, @@inf, @@enhanced_str, @@enhanced_con, @@enhanced_dex, @@enhanced_agi, @@enhanced_dis, @@enhanced_aur, @@enhanced_log, @@enhanced_int, @@enhanced_wis, @@enhanced_inf]
      end

      def Stats.load_serialized=(array)
        for i in 16..25
          array[i] ||= [0, 0]
        end
        @@race, @@prof, @@gender, @@age = array[0..3]
        @@level, @@str, @@con, @@dex, @@agi, @@dis, @@aur, @@log, @@int, @@wis, @@inf, @@enhanced_str, @@enhanced_con, @@enhanced_dex, @@enhanced_agi, @@enhanced_dis, @@enhanced_aur, @@enhanced_log, @@enhanced_int, @@enhanced_wis, @@enhanced_inf = array[5..25]
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

    module Effects
      class Registry
        include Enumerable

        def initialize(dialog)
          @dialog = dialog
        end

        def to_h
          XMLData.dialogs.fetch(@dialog, {})
        end

        def each()
          to_h.each { |k, v| yield(k, v) }
        end

        def active?(effect)
          expiry = to_h.fetch(effect, 0)
          expiry.to_f > Time.now.to_f
        end

        def time_left(effect)
          expiry = to_h.fetch(effect, 0)
          if to_h.fetch(effect, 0) != 0
            ((expiry - Time.now) / 60.to_f)
          else
            expiry
          end
        end
      end

      Spells    = Registry.new("Active Spells")
      Buffs     = Registry.new("Buffs")
      Debuffs   = Registry.new("Debuffs")
      Cooldowns = Registry.new("Cooldowns")
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

      def Wounds.method_missing(arg = nil)
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

      def Scars.method_missing(arg = nil)
        echo "Scars: Invalid area, try one of these: arms, limbs, torso, #{XMLData.injuries.keys.join(', ')}"
        nil
      end
    end
    class GameObj
      @@loot          = Array.new
      @@npcs          = Array.new
      @@npc_status    = Hash.new
      @@pcs           = Array.new
      @@pc_status     = Hash.new
      @@inv           = Array.new
      @@contents      = Hash.new
      @@right_hand    = nil
      @@left_hand     = nil
      @@room_desc     = Array.new
      @@fam_loot      = Array.new
      @@fam_npcs      = Array.new
      @@fam_pcs       = Array.new
      @@fam_room_desc = Array.new
      @@type_data     = Hash.new
      @@sellable_data = Hash.new
      @@elevated_load = proc { GameObj.load_data }

      attr_reader :id
      attr_accessor :noun, :name, :before_name, :after_name

      def initialize(id, noun, name, before = nil, after = nil)
        @id = id
        @noun = noun
        @noun = 'lapis' if @noun == 'lapis lazuli'
        @noun = 'hammer' if @noun == "Hammer of Kai"
        @noun = 'ball' if @noun == "ball and chain" # DR item 'ball and chain' doesn't work.
        @noun = 'mother-of-pearl' if (@noun == 'pearl') and (@name =~ /mother\-of\-pearl/)
        @name = name
        @before_name = before
        @after_name = after
      end

      def type
        GameObj.load_data if @@type_data.empty?
        list = @@type_data.keys.find_all { |t| (@name =~ @@type_data[t][:name] or @noun =~ @@type_data[t][:noun]) and (@@type_data[t][:exclude].nil? or @name !~ @@type_data[t][:exclude]) }
        if list.empty?
          nil
        else
          list.join(',')
        end
      end

      def sellable
        GameObj.load_data if @@sellable_data.empty?
        list = @@sellable_data.keys.find_all { |t| (@name =~ @@sellable_data[t][:name] or @noun =~ @@sellable_data[t][:noun]) and (@@sellable_data[t][:exclude].nil? or @name !~ @@sellable_data[t][:exclude]) }
        if list.empty?
          nil
        else
          list.join(',')
        end
      end

      def status
        if @@npc_status.keys.include?(@id)
          @@npc_status[@id]
        elsif @@pc_status.keys.include?(@id)
          @@pc_status[@id]
        elsif @@loot.find { |obj| obj.id == @id } or @@inv.find { |obj| obj.id == @id } or @@room_desc.find { |obj| obj.id == @id } or @@fam_loot.find { |obj| obj.id == @id } or @@fam_npcs.find { |obj| obj.id == @id } or @@fam_pcs.find { |obj| obj.id == @id } or @@fam_room_desc.find { |obj| obj.id == @id } or (@@right_hand.id == @id) or (@@left_hand.id == @id) or @@contents.values.find { |list| list.find { |obj| obj.id == @id } }
          nil
        else
          'gone'
        end
      end

      def status=(val)
        if @@npcs.any? { |npc| npc.id == @id }
          @@npc_status[@id] = val
        elsif @@pcs.any? { |pc| pc.id == @id }
          @@pc_status[@id] = val
        else
          nil
        end
      end

      def to_s
        @noun
      end

      def empty?
        false
      end

      def contents
        @@contents[@id].dup
      end

      def GameObj.[](val)
        if val.class == String
          if val =~ /^\-?[0-9]+$/
            obj = @@inv.find { |o| o.id == val } || @@loot.find { |o| o.id == val } || @@npcs.find { |o| o.id == val } || @@pcs.find { |o| o.id == val } || [@@right_hand, @@left_hand].find { |o| o.id == val } || @@room_desc.find { |o| o.id == val }
          elsif val.split(' ').length == 1
            obj = @@inv.find { |o| o.noun == val } || @@loot.find { |o| o.noun == val } || @@npcs.find { |o| o.noun == val } || @@pcs.find { |o| o.noun == val } || [@@right_hand, @@left_hand].find { |o| o.noun == val } || @@room_desc.find { |o| o.noun == val }
          else
            obj = @@inv.find { |o| o.name == val } || @@loot.find { |o| o.name == val } || @@npcs.find { |o| o.name == val } || @@pcs.find { |o| o.name == val } || [@@right_hand, @@left_hand].find { |o| o.name == val } || @@room_desc.find { |o| o.name == val } || @@inv.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@loot.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@npcs.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@pcs.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || [@@right_hand, @@left_hand].find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@room_desc.find { |o| o.name =~ /\b#{Regexp.escape(val.strip)}$/i } || @@inv.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@loot.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@npcs.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@pcs.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || [@@right_hand, @@left_hand].find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i } || @@room_desc.find { |o| o.name =~ /\b#{Regexp.escape(val).sub(' ', ' .*')}$/i }
          end
        elsif val.class == Regexp
          obj = @@inv.find { |o| o.name =~ val } || @@loot.find { |o| o.name =~ val } || @@npcs.find { |o| o.name =~ val } || @@pcs.find { |o| o.name =~ val } || [@@right_hand, @@left_hand].find { |o| o.name =~ val } || @@room_desc.find { |o| o.name =~ val }
        end
      end

      def GameObj
        @noun
      end

      def full_name
        "#{@before_name}#{' ' unless @before_name.nil? or @before_name.empty?}#{name}#{' ' unless @after_name.nil? or @after_name.empty?}#{@after_name}"
      end

      def GameObj.new_npc(id, noun, name, status = nil)
        obj = GameObj.new(id, noun, name)
        @@npcs.push(obj)
        @@npc_status[id] = status
        obj
      end

      def GameObj.new_loot(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@loot.push(obj)
        obj
      end

      def GameObj.new_pc(id, noun, name, status = nil)
        obj = GameObj.new(id, noun, name)
        @@pcs.push(obj)
        @@pc_status[id] = status
        obj
      end

      def GameObj.new_inv(id, noun, name, container = nil, before = nil, after = nil)
        obj = GameObj.new(id, noun, name, before, after)
        if container
          @@contents[container].push(obj)
        else
          @@inv.push(obj)
        end
        obj
      end

      def GameObj.new_room_desc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@room_desc.push(obj)
        obj
      end

      def GameObj.new_fam_room_desc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_room_desc.push(obj)
        obj
      end

      def GameObj.new_fam_loot(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_loot.push(obj)
        obj
      end

      def GameObj.new_fam_npc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_npcs.push(obj)
        obj
      end

      def GameObj.new_fam_pc(id, noun, name)
        obj = GameObj.new(id, noun, name)
        @@fam_pcs.push(obj)
        obj
      end

      def GameObj.new_right_hand(id, noun, name)
        @@right_hand = GameObj.new(id, noun, name)
      end

      def GameObj.right_hand
        @@right_hand.dup
      end

      def GameObj.new_left_hand(id, noun, name)
        @@left_hand = GameObj.new(id, noun, name)
      end

      def GameObj.left_hand
        @@left_hand.dup
      end

      def GameObj.clear_loot
        @@loot.clear
      end

      def GameObj.clear_npcs
        @@npcs.clear
        @@npc_status.clear
      end

      def GameObj.clear_pcs
        @@pcs.clear
        @@pc_status.clear
      end

      def GameObj.clear_inv
        @@inv.clear
      end

      def GameObj.clear_room_desc
        @@room_desc.clear
      end

      def GameObj.clear_fam_room_desc
        @@fam_room_desc.clear
      end

      def GameObj.clear_fam_loot
        @@fam_loot.clear
      end

      def GameObj.clear_fam_npcs
        @@fam_npcs.clear
      end

      def GameObj.clear_fam_pcs
        @@fam_pcs.clear
      end

      def GameObj.npcs
        if @@npcs.empty?
          nil
        else
          @@npcs.dup
        end
      end

      def GameObj.loot
        if @@loot.empty?
          nil
        else
          @@loot.dup
        end
      end

      def GameObj.pcs
        if @@pcs.empty?
          nil
        else
          @@pcs.dup
        end
      end

      def GameObj.inv
        if @@inv.empty?
          nil
        else
          @@inv.dup
        end
      end

      def GameObj.room_desc
        if @@room_desc.empty?
          nil
        else
          @@room_desc.dup
        end
      end

      def GameObj.fam_room_desc
        if @@fam_room_desc.empty?
          nil
        else
          @@fam_room_desc.dup
        end
      end

      def GameObj.fam_loot
        if @@fam_loot.empty?
          nil
        else
          @@fam_loot.dup
        end
      end

      def GameObj.fam_npcs
        if @@fam_npcs.empty?
          nil
        else
          @@fam_npcs.dup
        end
      end

      def GameObj.fam_pcs
        if @@fam_pcs.empty?
          nil
        else
          @@fam_pcs.dup
        end
      end

      def GameObj.clear_container(container_id)
        @@contents[container_id] = Array.new
      end

      def GameObj.delete_container(container_id)
        @@contents.delete(container_id)
      end

      def GameObj.targets
        a = Array.new
        XMLData.current_target_ids.each { |id|
          if (npc = @@npcs.find { |n| n.id == id }) and (npc.status !~ /dead|gone/)
            a.push(npc)
          end
        }
        a
      end

      def GameObj.dead
        dead_list = Array.new
        for obj in @@npcs
          dead_list.push(obj) if obj.status == "dead"
        end
        return nil if dead_list.empty?

        return dead_list
      end

      def GameObj.containers
        @@contents.dup
      end

      def GameObj.load_data(filename = nil)
        if $SAFE == 0
          if filename.nil?
            if File.exists?("#{DATA_DIR}/gameobj-data.xml")
              filename = "#{DATA_DIR}/gameobj-data.xml"
            elsif File.exists?("#{SCRIPT_DIR}/gameobj-data.xml") # deprecated
              filename = "#{SCRIPT_DIR}/gameobj-data.xml"
            else
              filename = "#{DATA_DIR}/gameobj-data.xml"
            end
          end
          if File.exists?(filename)
            begin
              @@type_data = Hash.new
              @@sellable_data = Hash.new
              File.open(filename) { |file|
                doc = REXML::Document.new(file.read)
                doc.elements.each('data/type') { |e|
                  if type = e.attributes['name']
                    @@type_data[type] = Hash.new
                    @@type_data[type][:name]    = Regexp.new(e.elements['name'].text) unless e.elements['name'].text.nil? or e.elements['name'].text.empty?
                    @@type_data[type][:noun]    = Regexp.new(e.elements['noun'].text) unless e.elements['noun'].text.nil? or e.elements['noun'].text.empty?
                    @@type_data[type][:exclude] = Regexp.new(e.elements['exclude'].text) unless e.elements['exclude'].text.nil? or e.elements['exclude'].text.empty?
                  end
                }
                doc.elements.each('data/sellable') { |e|
                  if sellable = e.attributes['name']
                    @@sellable_data[sellable] = Hash.new
                    @@sellable_data[sellable][:name]    = Regexp.new(e.elements['name'].text) unless e.elements['name'].text.nil? or e.elements['name'].text.empty?
                    @@sellable_data[sellable][:noun]    = Regexp.new(e.elements['noun'].text) unless e.elements['noun'].text.nil? or e.elements['noun'].text.empty?
                    @@sellable_data[sellable][:exclude] = Regexp.new(e.elements['exclude'].text) unless e.elements['exclude'].text.nil? or e.elements['exclude'].text.empty?
                  end
                }
              }
              true
            rescue
              @@type_data = nil
              @@sellable_data = nil
              echo "error: GameObj.load_data: #{$!}"
              respond $!.backtrace[0..1]
              false
            end
          else
            @@type_data = nil
            @@sellable_data = nil
            echo "error: GameObj.load_data: file does not exist: #{filename}"
            false
          end
        else
          @@elevated_load.call
        end
      end

      def GameObj.type_data
        @@type_data
      end

      def GameObj.sellable_data
        @@sellable_data
      end
    end
    #
    # start deprecated stuff
    #
    class RoomObj < GameObj
    end
    #
    # end deprecated stuff
    #
  end
  module DragonRealms
    # fixme
  end
end
