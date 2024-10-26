# frozen_string_literal: true

module DRParser
  module Pattern
    ExpColumns = /(?:\s*(?<skill>[a-zA-Z\s]+)\b:\s*(?<rank>\d+)\s+(?<percent>\d+)%\s+(?<rate>[a-zA-Z\s]+)\b)/
    BriefExpOn = %r{<component id='exp .*?<d cmd='skill (?<skill>[a-zA-Z\s]+)'.*:\s+(?<rank>\d+)\s+(?<percent>\d+)%\s*\[\s?(?<rate>\d+)\/34\].*?<\/component>}
    BriefExpOff = %r{<component id='exp .*?\b(?<skill>[a-zA-Z\s]+)\b:\s+(?<rank>\d+)\s+(?<percent>\d+)%\s+\b(?<rate>[a-zA-Z\s]+)\b.*?<\/component>}
    NameRaceGuild = /^Name:\s+\b(?<name>.+)\b\s+Race:\s+\b(?<race>.+)\b\s+Guild:\s+\b(?<guild>.+)\b\s+/
    GenderAgeCircle = /^Gender:\s+\b(?<gender>.+)\b\s+Age:\s+\b(?<age>.+)\b\s+Circle:\s+\b(?<circle>.+)/
    StatValue = /(?<stat>Strength|Agility|Discipline|Intelligence|Reflex|Charisma|Wisdom|Stamina|Favors|TDPs)\s+:\s+(?<value>\d+)/
    EncumbranceValue = /^\s*Encumbrance\s+:\s+(?<encumbrance>[\w\s'?!]+)$/
    LuckValue = /^\s*Luck\s+:\s+.*\((?<luck>[-\d]+)\/3\)/
    BalanceValue = /^(?:You are|\[You're) (?<balance>#{Regexp.union(DR_BALANCE_VALUES)}) balanced?/
    ExpClearMindstate = %r{<component id='exp (?<skill>[a-zA-Z\s]+)'><\/component>}
    RoomPlayers = %r{\'room players\'>Also here: (.*)\.</component>}
    RoomPlayersEmpty = %r{\'room players\'></component>}
    RoomObjs = %r{\'room objs\'>(.*)</component>}
    RoomObjsEmpty = %r{\'room objs\'></component>}
    RoomExits = /Obvious (exits|paths):/
    GroupMembers = %r{<pushStream id="group"/>  (\w+):}
    GroupMembersEmpty = %r{<pushStream id="group"/>Members of your group:}
  end

  def self.parse(line)
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
      when Pattern::BalanceValue
        DRStats.balance = DR_BALANCE_VALUES.index(Regexp.last_match[:balance])
      when Pattern::RoomPlayersEmpty
        DRRoom.pcs = []
      when Pattern::RoomPlayers
        DRRoom.pcs = find_pcs(Regexp.last_match(1).dup)
        DRRoom.pcs_prone = find_pcs_prone(Regexp.last_match(1).dup)
        DRRoom.pcs_sitting = find_pcs_sitting(Regexp.last_match(1).dup)
      when RoomObjs
        DRRoom.npcs = find_npcs(Regexp.last_match(1).dup)
        UserVars.npcs = DRRoom.npcs
        DRRoom.dead_npcs = find_dead_npcs(Regexp.last_match(1).dup)
        DRRoom.room_objs = find_objects(Regexp.last_match(1).dup)
      when RoomObjsEmpty
        DRRoom.npcs = []
        DRRoom.dead_npcs = []
        DRRoom.room_objs = []
      when GroupMembersEmpty
        DRRoom.group_members = []
      when GroupMembers
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
        # Lich.log(line)
        :ok
        line.scan(Pattern::ExpColumns) do |skill_value, rank_value, percent_value, rate_as_word|
          rate_as_number = DR_LEARNING_RATES.index(rate_as_word) # convert word to number
          DRSkill.update(skill_value, rank_value, rate_as_number, percent_value)
        end
      else
        :noop
      end
    rescue StandardError
      # respond "--- Lich: error: Infomon::Parser.parse: #{$!}"
      # respond "--- Lich: error: line: #{line}"
      # Lich.log "error: Infomon::Parser.parse: #{$!}\n\t#{$!.backtrace.join("\n\t")}"
      # Lich.log "error: line: #{line}\n\t"
    end
  end
end
