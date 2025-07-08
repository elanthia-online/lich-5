# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRParser
      module Pattern
        ExpColumns = /(?:\s*(?<skill>[a-zA-Z\s]+)\b:\s*(?<rank>\d+)\s+(?<percent>\d+)%\s+(?<rate>[a-zA-Z\s]+)\b)/.freeze
        BriefExpOn = %r{<component id='exp .*?<d cmd='skill (?<skill>[a-zA-Z\s]+)'.*:\s+(?<rank>\d+)\s+(?<percent>\d+)%\s*\[\s?(?<rate>\d+)\/34\].*?<\/component>}.freeze
        BriefExpOff = %r{<component id='exp .*?\b(?<skill>[a-zA-Z\s]+)\b:\s+(?<rank>\d+)\s+(?<percent>\d+)%\s+\b(?<rate>[a-zA-Z\s]+)\b.*?<\/component>}.freeze
        NameRaceGuild = /^Name:\s+\b(?<name>.+)\b\s+Race:\s+\b(?<race>.+)\b\s+Guild:\s+\b(?<guild>.+)\b\s+/.freeze
        GenderAgeCircle = /^Gender:\s+\b(?<gender>.+)\b\s+Age:\s+\b(?<age>.+)\b\s+Circle:\s+\b(?<circle>.+)/.freeze
        StatValue = /(?<stat>Strength|Agility|Discipline|Intelligence|Reflex|Charisma|Wisdom|Stamina|Favors|TDPs)\s+:\s+(?<value>\d+)/.freeze
        TDPValue = /You have (\d+) TDPs\./.freeze
        EncumbranceValue = /^\s*Encumbrance\s+:\s+(?<encumbrance>[\w\s'?!]+)$/.freeze
        LuckValue = /^\s*Luck\s+:\s+.*\((?<luck>[-\d]+)\/3\)/.freeze
        BalanceValue = /^(?:You are|\[You're) (?<balance>#{Regexp.union(DR_BALANCE_VALUES)}) balanced?/.freeze
        ExpClearMindstate = %r{<component id='exp (?<skill>[a-zA-Z\s]+)'><\/component>}.freeze
        RoomPlayers = %r{\'room players\'>Also here: (.*)\.</component>}.freeze
        RoomPlayersEmpty = %r{\'room players\'></component>}.freeze
        RoomObjs = %r{\'room objs\'>(.*)</component>}.freeze
        RoomObjsEmpty = %r{\'room objs\'></component>}.freeze
        GroupMembers = %r{<pushStream id="group"/>  (\w+):}.freeze
        GroupMembersEmpty = %r{<pushStream id="group"/>Members of your group:}.freeze
        ExpModsStart = /^(<.*?\/>)?The following skills are currently under the influence of a modifier/.freeze
        KnownSpellsStart = /^You recall the spells you have learned/.freeze
        BarbarianAbilitiesStart = /^You know the (Berserks:)/.freeze
        ThiefKhriStart = /^From the Subtlety tree, you know the following khri:/.freeze
        SpellBookFormat = /^You will .* (?<format>column-formatted|non-column) output for the SPELLS verb/.freeze
        PlayedAccount = /^(?:<.*?\/>)?Account Info for (?<account>.+):/.freeze
        PlayedSubscription = /Current Account Status: (?<subscription>F2P|Basic|Premium|Platinum)/.freeze
        LastLogoff = /^\s+Logoff :  (?<weekday>[A-Z][a-z]{2}) (?<month>[A-Z][a-z]{2}) (?<day>[\s\d]{2}) (?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2}) ET (?<year>\d{4})/.freeze
        RoomIDOff = /^You will no longer see room IDs when LOOKing in the game and room windows\./.freeze
      end

      @parsing_exp_mods_output = false

      def self.check_events(server_string)
        Flags.matchers.each do |key, regexes|
          regexes.each do |regex|
            if (matches = server_string.match(regex))
              Flags.flags[key] = matches
              break
            end
          end
        end
        server_string
      end

      def self.check_exp_mods(server_string)
        # This method parses the output from `exp mods` command
        # and updates the DRSkill.exp_modifiers hash with the skill and value.
        # This is primarily used by the `skill-recorder` script.
        #
        # Example output without any modifiers:
        #     The following skills are currently under the influence of a modifier:
        #     <output class="mono"/>
        #       None
        #     <output class=""/>
        #
        # Example output with modifiers:
        #     The following skills are currently under the influence of a modifier:
        #     <output class="mono"/>
        #     +75 Athletics
        #     -10 Evasion
        #     <output class=""/>
        #
        # Zero or more skills may be listed between the <output> tags
        # but exactly one skill and its skill modifier are listed per line.
        # The number is signed to indicate a buff (+) or debuff (-).
        #
        case server_string
        when %r{^<output class=""/>}
          if @parsing_exp_mods_output
            @parsing_exp_mods_output = false
          end
        else
          if @parsing_exp_mods_output
            # https://regex101.com/r/5ZE8lq/1
            match = /^(?<sign>[+-])(?<value>\d+)\s+(?<skill>[\w\s]+)$/.match(server_string)
            if match
              skill = match[:skill].strip
              sign = match[:sign]
              value = match[:value].to_i
              value = (value * -1) if sign == '-'
              DRSkill.update_mods(skill, value)
            end
          end
        end
        server_string
      end

      def self.check_known_spells(server_string)
        # This method parses the output from `spells` command for magic users
        # and populates the known spells/feats based on the output.
        #
        # As of June 2022, There are two different output formats: column-formatted and non-column.
        # https://elanthipedia.play.net/Post:Tuesday_Tidings_-_120_-_Spells_-_06/07/2022_-_18:34
        #
        # The XML stream for DragonRealms is whack at best.
        #
        # Examples of non-column output:
        #     You recall the spells you have learned from your training.
        #     In the chapter entitled "Analogous Patterns", you have notes on the Manifest Force [maf] and Gauge Flow [gaf] spells.
        #     You have temporarily memorized the Tailwind [tw] spell.
        #     You recall proficiency with the magic feats of Sorcerous Patterns, Alternate Preparation and Augmentation Mastery.
        #     You are NOT currently set to recognize known spells when prepared by someone else in the area.  (Use SPELL RECOGNIZE ON to change this.)
        #     You are currently set to display full cast messaging.  (Use SPELL BRIEFMSG ON to change this.)
        #     You are currently attempting to hide your spell preparing.  (Use PREPARE /HIDE to change this.)
        #     You can use SPELL STANCE [HELP] to view or modify your spellcasting preferences.
        #
        # Examples of column-formatted output:
        #     You recall the spells you have learned from your training.
        #     <output class="mono"/>
        #     <pushBold/>
        #     Analogous Patterns:
        #     <popBold/>     maf  Manifest Force                  Slot(s): 1   Min Prep: 1     Max Prep: 100
        #          gaf  Gauge Flow                      Slot(s): 2   Min Prep: 5     Max Prep: 100
        #     <pushBold/>
        #     Synthetic Creation:
        #     <popBold/>     acs  Acid Splash                     Slot(s): 1   Min Prep: 1     Max Prep: 50
        #           vs  Viscous Solution                Slot(s): 2   Min Prep: 10    Max Prep: 66
        #     <output class=""/>
        #     <output class="mono"/>
        #     <pushBold/>
        #     Temporarily Memorized:
        #     <popBold/>      tw  Tailwind                        Slot(s): 1   Min Prep: 5     Max Prep: 100
        #     <output class=""/>
        #     You recall proficiency with the magic feats of Sorcerous Patterns, Alternate Preparation and Augmentation Mastery.
        #     You are NOT currently set to recognize known spells when prepared by someone else in the area.  (Use SPELL RECOGNIZE ON to change this.)
        #     You are currently set to display full cast messaging.  (Use SPELL BRIEFMSG ON to change this.)
        #     You are currently attempting to hide your spell preparing.  (Use PREPARE /HIDE to change this.)
        #     You can use SPELL STANCE [HELP] to view or modify your spellcasting preferences.
        #
        # One or more spells may be listed between a <popBold/> <pushBold/> pair,
        # but only one spell and its information are ever listed per line.
        case server_string
        when /^<output class="mono"\/>/
          # Matched an xml tag while parsing spells, must be column-formatted output
          if DRSpells.grabbing_known_spells
            DRSpells.spellbook_format = 'column-formatted'
          end
        when /^[\w\s]+:/
          # Matched the spellbook name in column-formatted output, ignore
        when /Slot\(s\): \d+ \s+ Min Prep: \d+ \s+ Max Prep: \d+/
          # Matched the spell info in column-formatted output, parse
          if DRSpells.grabbing_known_spells && DRSpells.spellbook_format == 'column-formatted'
            spell = server_string
                    .sub('<popBold/>', '') # remove xml tag at start of some lines
                    .slice(10, 32) # grab the spell name, after the alias and before Slots
                    .strip
            if !spell.empty?
              DRSpells.known_spells[spell] = true
            end
          end
          # Preserve the pop bold command we removed from start of spell line
          # otherwise lots of game text suddenly are highlighted yellow
        when /^In the chapter entitled|^You have temporarily memorized|^From your apprenticeship you remember practicing/
          if DRSpells.grabbing_known_spells
            server_string
              .sub(/^In the chapter entitled "[\w\s\'-]+", you have notes on the /, '')
              .sub(/^You have temporarily memorized the /, '')
              .sub(/^From your apprenticeship you remember practicing with the /, '')
              .sub(/ spells?\./, '')
              .sub(/,? and /, ',')
              .split(',')
              .map { |mapped_spell| mapped_spell.include?('[') ? mapped_spell.slice(0, mapped_spell.index('[')) : mapped_spell }
              .map(&:strip)
              .reject { |rejected_spell| rejected_spell.nil? || rejected_spell.empty? }
              .each { |each_spell| DRSpells.known_spells[each_spell] = true }
          end
        when /^You recall proficiency with the magic feats of/
          if DRSpells.grabbing_known_spells
            # The feats are listed without the Oxford comma separating the last item.
            # This makes splitting the string by comma difficult because the next to last and last
            # items would be captured together. The workaround is we'll replace ' and ' with a comma
            # and hope no feats ever have the word 'and' in them...
            server_string
              .sub(/^You recall proficiency with the magic feats of/, '')
              .sub(/,? and /, ',')
              .sub('.', '')
              .split(',')
              .map(&:strip)
              .reject { |feat| feat.nil? || feat.empty? }
              .each { |feat| DRSpells.known_feats[feat] = true }
          end
        when /^You can use SPELL STANCE|^You have (no|yet to receive any) training in the magical arts|You have no desire to soil yourself with magical trickery|^You really shouldn't be loitering here|\(Use SPELL|\(Use PREPARE/
          DRSpells.grabbing_known_spells = false
        end
        server_string
      end

      def self.check_known_barbarian_abilities(server_string)
        # This method parses the output from `ability` command for Barbarians
        # and populates the known spells/feats based on the known abilities/masteries.
        #
        # The XML stream for DragonRealms is whack at best.
        #
        # Examples of the data we're looking for:
        #     You know the Berserks:<pushBold/> Avalanche, Drought.
        #     <popBold/>You know the Forms:<pushBold/> Monkey.
        #     <popBold/>You know the Roars:<pushBold/> Anger the Earth.
        #     <popBold/>You know the Meditations:<pushBold/> Flame, Power, Contemplation.
        #     <popBold/>You know the Masteries:<pushBold/> Juggernaut, Duelist.
        #     <popBold/>
        #     You recall that you have 0 training sessions remaining with the Guild.
        case server_string
        when /^(<(push|pop)Bold\/>)?You know the (Berserks|Forms|Roars|Meditations):(<(push|pop)Bold\/>)?/
          if DRSpells.check_known_barbarian_abilities
            server_string
              .sub(/^(<(push|pop)Bold\/>)?You know the (Berserks|Forms|Roars|Meditations):(<(push|pop)Bold\/>)?/, '')
              .sub('.', '')
              .split(',')
              .map(&:strip)
              .reject { |ability| ability.nil? || ability.empty? }
              .each { |ability| DRSpells.known_spells[ability] = true }
          end
        when /^(<(push|pop)Bold\/>)?You know the (Masteries):(<(push|pop)Bold\/>)?/
          # Barbarian masteries are the equivalent of magical feats.
          if DRSpells.check_known_barbarian_abilities
            server_string
              .sub(/^(<(push|pop)Bold\/>)?You know the (Masteries):(<(push|pop)Bold\/>)?/, '')
              .sub('.', '')
              .split(',')
              .map(&:strip)
              .reject { |mastery| mastery.nil? || mastery.empty? }
              .each { |mastery| DRSpells.known_feats[mastery] = true }
          end
        when /^You recall that you have (\d+) training sessions? remaining with the Guild/
          DRSpells.check_known_barbarian_abilities = false
        end
        server_string
      end

      def self.check_known_thief_khri(server_string)
        # This method parses the output from `ability` command for Thieves
        # and populates the known spells/feats based on the known khri.
        #
        # The XML stream for DragonRealms is whack at best.
        #
        # Examples of the data we're looking for:
        #     From the Subtlety tree, you know the following khri: Darken (Aug), Dampen (Util/Ward), Strike (Aug), Silence (Util), Shadowstep (Util), Harrier (Aug)
        #     From the Finesse tree, you know the following khri: Hasten (Util), Safe (Aug), Avoidance (Aug), Plunder (Aug), Flight (Aug/Ward), Elusion (Aug), Slight (Util)
        #     From the Potence tree, you know the following khri: Focus (Aug), Prowess (Debil), Sight (Aug), Calm (Util), Steady (Aug), Eliminate (Debil), Serenity (Ward), Sagacity (Ward), Terrify (Debil)
        #     You have 7 available slots.
        case server_string
        when /^From the (Subtlety|Finesse|Potence) tree, you know the following khri:/
          if DRSpells.grabbing_known_khri
            server_string
              .sub(/^From the (Subtlety|Finesse|Potence) tree, you know the following khri:/, '')
              .sub('.', '')
              .gsub(/\(.+?\)/, '')
              .split(',')
              .map(&:strip)
              .reject { |ability| ability.nil? || ability.empty? }
              .each { |ability| DRSpells.known_spells[ability] = true }
          end
        when /^You have (\d+) available slots?/
          DRSpells.grabbing_known_khri = false
        end
        server_string
      end

      def self.parse(line)
        check_events(line)
        begin
          case line
          when Pattern::GenderAgeCircle
            DRStats.gender = Regexp.last_match[:gender]
            DRStats.age = Regexp.last_match[:age].to_i
            DRStats.circle = Regexp.last_match[:circle].to_i
          when Pattern::NameRaceGuild
            DRStats.race = Regexp.last_match[:race]
            DRStats.guild = Regexp.last_match[:guild]
          when Pattern::EncumbranceValue
            DRStats.encumbrance = Regexp.last_match[:encumbrance]
          when Pattern::LuckValue
            DRStats.luck = Regexp.last_match[:luck].to_i
          when Pattern::StatValue
            line.scan(Pattern::StatValue) do |stat, value|
              DRStats.send("#{stat.downcase}=", value.to_i)
            end
          when Pattern::TDPValue
            DRStats.tdps = Regexp.last_match(1).to_i
            # CharSettings['Stats'] = DRStats.serialize
          when Pattern::BalanceValue
            DRStats.balance = DR_BALANCE_VALUES.index(Regexp.last_match[:balance])
          when Pattern::RoomPlayersEmpty
            DRRoom.pcs = []
          when Pattern::RoomPlayers
            DRRoom.pcs = find_pcs(Regexp.last_match(1).dup)
            DRRoom.pcs_prone = find_pcs_prone(Regexp.last_match(1).dup)
            DRRoom.pcs_sitting = find_pcs_sitting(Regexp.last_match(1).dup)
          when Pattern::RoomObjs
            DRRoom.npcs = find_npcs(Regexp.last_match(1).dup)
            UserVars.npcs = DRRoom.npcs
            DRRoom.dead_npcs = find_dead_npcs(Regexp.last_match(1).dup)
            DRRoom.room_objs = find_objects(Regexp.last_match(1).dup)
          when Pattern::RoomObjsEmpty
            DRRoom.npcs = []
            DRRoom.dead_npcs = []
            DRRoom.room_objs = []
          when Pattern::GroupMembersEmpty
            DRRoom.group_members = []
          when Pattern::GroupMembers
            DRRoom.group_members << Regexp.last_match(1)
          when Pattern::BriefExpOn, Pattern::BriefExpOff
            skill   = Regexp.last_match[:skill]
            rank    = Regexp.last_match[:rank].to_i
            rate    = Regexp.last_match[:rate].to_i > 0 ? Regexp.last_match[:rate] : DR_LEARNING_RATES.index(Regexp.last_match[:rate])
            percent = Regexp.last_match[:percent]
            DRSkill.update(skill, rank, rate, percent)
          when Pattern::ExpClearMindstate
            skill = Regexp.last_match[:skill]
            DRSkill.clear_mind(skill)
          when Pattern::ExpColumns
            line.scan(Pattern::ExpColumns) do |skill_value, rank_value, percent_value, rate_as_word|
              rate_as_number = DR_LEARNING_RATES.index(rate_as_word) # convert word to number
              DRSkill.update(skill_value, rank_value, rate_as_number, percent_value)
            end
          when Pattern::ExpModsStart
            @parsing_exp_mods_output = true
            DRSkill.exp_modifiers.clear
          when Pattern::SpellBookFormat
            # Parse `toggle spellbook` command
            DRSpells.spellbook_format = Regexp.last_match[:format]
          when Pattern::KnownSpellsStart
            DRSpells.grabbing_known_spells = true
            DRSpells.known_spells.clear()
            DRSpells.known_feats.clear()
            DRSpells.spellbook_format = 'non-column' # assume original format
          when Pattern::BarbarianAbilitiesStart
            DRSpells.check_known_barbarian_abilities = true
            DRSpells.known_spells.clear()
            DRSpells.known_feats.clear()
          when Pattern::ThiefKhriStart
            DRSpells.grabbing_known_khri = true
            DRSpells.known_spells.clear()
            DRSpells.known_feats.clear()
          when Pattern::PlayedAccount
            if Account.name.nil?
              Account.name = Regexp.last_match[:account].upcase
            end
          when Pattern::PlayedSubscription
            if Account.subscription.nil?
              Account.subscription = Regexp.last_match[:subscription].gsub('Basic', 'Normal').gsub('F2P', 'Free').gsub('Platinum', 'Premium').upcase
            end
            UserVars.account_type = Regexp.last_match[:subscription].gsub('Basic', 'Normal').gsub('F2P', 'Free').upcase
            if Account.subscription == 'PREMIUM' || XMLData.game == 'DRX' || XMLData.game == 'DRF'
              UserVars.premium = true
            else
              UserVars.premium = false
            end
          when Pattern::LastLogoff
            matches = Regexp.last_match
            month = Date::ABBR_MONTHNAMES.find_index(matches[:month])
            weekdays = [nil, 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            dst_check = matches[:day].to_i - weekdays.find_index(matches[:weekday])
            if month.between?(4, 10) || (month == 3 && dst_check >= 7) || (month == 11 && dst_check < 0)
              tz = '-0400'
            else
              tz = '-0500'
            end
            $last_logoff = Time.new(matches[:year].to_i, month, matches[:day].to_i, matches[:hour].to_i, matches[:minute].to_i, matches[:second].to_i, tz).getlocal
          when Pattern::RoomIDOff
            put("flag showroomid on")
            respond("Lich requires ShowRoomID to be ON for mapping to work, please do not turn this off.")
            respond("If you wish to hide the Real ID#, you can toggle it off by doing ;display flaguid")
          else
            :noop
          end

          check_exp_mods(line) if @parsing_exp_mods_output
          check_known_barbarian_abilities(line) if DRSpells.check_known_barbarian_abilities
          check_known_thief_khri(line) if DRSpells.grabbing_known_khri
          check_known_spells(line) if DRSpells.grabbing_known_spells
        rescue StandardError
          respond "--- Lich: error: DRParser.parse: #{$!}"
          respond "--- Lich: error: line: #{line}"
          Lich.log "error: DRParser.parse: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
          Lich.log "error: line: #{line}\n\t"
        end
      end
    end
  end
end
