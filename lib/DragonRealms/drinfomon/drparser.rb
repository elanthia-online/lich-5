# frozen_string_literal: true

module Lich
  module DragonRealms
    module DRInfomon

module DRParser
  Lich.log("DRParser Caller location is #{caller_locations(0)}")

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
    RoomExits = /Obvious (exits|paths):/.freeze
    GroupMembers = %r{<pushStream id="group"/>  (\w+):}.freeze
    GroupMembersEmpty = %r{<pushStream id="group"/>Members of your group:}.freeze
    ExpModsStart = /^(<.*?\/>)?The following skills are currently under the influence of a modifier/.freeze
    MultiEnd = %r{^<output class=""/>}.freeze
    ExpMods = /^<preset id="speech">(?<sign>\+|\-)+(?<value>\d+) \b(?<skill>[\w\s]+)\b<\/preset>/.freeze
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
        CharSettings['Stats'] = DRStats.serialize
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
      when Pattern::ExpMods
        if @parsing_exp_mods_output
          skill = Regexp.last_match[:skill]
          sign = Regexp.last_match[:sign]
          value = Regexp.last_match[:value].to_i
          value = (value * -1) if sign == '-'
          DRSkill.update_mods(skill, value)
        end
      when Pattern::MultiEnd
        @parsing_exp_mods_output = false
      when /^You will .* (?<format>column-formatted|non-column) output for the SPELLS verb/
        # Parse `toggle spellbook` command
        DRSpells.spellbook_format = Regexp.last_match[:format]
      when /^You recall the spells you have learned/
        DRSpells.grabbing_known_spells = true
        DRSpells.known_spells.clear()
        DRSpells.known_feats.clear()
        DRSpells.spellbook_format = 'non-column' # assume original format
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
          spell = line
                  .sub('<popBold/>', '') # remove xml tag at start of some lines
                  .slice(10, 32) # grab the spell name, after the alias and before Slots
                  .strip
          if !spell.empty?
            DRSpells.known_spells[spell] = true
          end
        end
      when /^In the chapter entitled|^You have temporarily memorized|^From your apprenticeship you remember practicing/
        if DRSpells.grabbing_known_spells
          line
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
          line
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
      when /^(<(push|pop)Bold\/>)?You know the (Berserks|Forms|Roars|Meditations):(<(push|pop)Bold\/>)?/
        DRSpells.grabbing_known_spells = true
        line
          .sub(/^(<(push|pop)Bold\/>)?You know the (Berserks|Forms|Roars|Meditations):(<(push|pop)Bold\/>)?/, '')
          .sub('.', '')
          .split(',')
          .map(&:strip)
          .reject { |ability| ability.nil? || ability.empty? }
          .each { |ability| DRSpells.known_spells[ability] = true }
      when /^(<(push|pop)Bold\/>)?You know the (Masteries):(<(push|pop)Bold\/>)?/
        # Barbarian masteries are the equivalent of magical feats.
        if DRSpells.grabbing_known_spells
          line
            .sub(/^(<(push|pop)Bold\/>)?You know the (Masteries):(<(push|pop)Bold\/>)?/, '')
            .sub('.', '')
            .split(',')
            .map(&:strip)
            .reject { |mastery| mastery.nil? || mastery.empty? }
            .each { |mastery| DRSpells.known_feats[mastery] = true }
        end
      when /^You recall that you have (\d+) training sessions? remaining with the Guild/
        DRSpells.grabbing_known_spells = false
      when /^From the (Subtlety|Finesse|Potence) tree, you know the following khri:/
        DRSpells.grabbing_known_spells = true
        line
          .sub(/^From the (Subtlety|Finesse|Potence) tree, you know the following khri:/, '')
          .sub('.', '')
          .gsub(/\(.+?\)/, '')
          .split(',')
          .map(&:strip)
          .reject { |ability| ability.nil? || ability.empty? }
          .each { |ability| DRSpells.known_spells[ability] = true }
      when /^You have (\d+) available slots?/
        DRSpells.grabbing_known_spells = false
      else
        :noop
      end
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
end
