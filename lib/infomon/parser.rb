module Infomon
  # this module handles all of the logic for parsing game lines that infomon depends on
  module Parser
    module Pattern
      Stat = %r[\s+(?<stat>\w+)\s\(\w{3}\):\s+(?<value>\d+)\s\((?<bonus>[\w-]+)\)\s+\.\.\.\s+(?<enhanced_value>\d+)\s\((?<enhanced_bonus>\w+)\)]
      Citizenship = /^You currently have .*? citizenship in (?<town>.*)\.$/
      NoCitizenship = /You don't seem to have citizenship\./
      Society = /^\s+You are a (?:Master|member) (?:in|of) the (?<society>Order of Voln|Council of Light|Guardians of Sunfist)(?: at rank (?<rank>[0-9]+)| at step (?<rank>[0-9]+))?\.$/
      NoSociety = %r[^\s+You are not a member of any society at this time.]
      PSM = %r[^\s+(?<name>[\w\s\-']+)\s+(?<command>[a-z]+)\s+(?<ranks>\d)\/(?<max>\d)\s+]
      Skill = %r[^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<bonus>\d+)\s+(?<ranks>\d+)]
      Spell = %r[^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<rank>\d+)$|^(?<name>[\w\s\-']+)\.+(?<rank>\d+)$]
      Levelup = %r[^\s+(?<stat>\w+)\s+\(\w{3}\)\s+:\s+(?<value>\d+)\s+(?:\+1)\s+\.\.\.\s+(?<bonus>\d+)(?:\s+\+1)?$]
      CharRaceProf = %r[^Name:\s+(?<name>[A-z\s']+)\s+Race:\s+(?<race>[-A-z\s]+)\s+Profession:\s+(?<profession>[-A-z\s]+)]
      CharGenderAgeExpLevel = %r[^Gender:\s+(?<gender>[A-z]+)\s+Age:\s+(?<age>[0-9]+)\s+Expr:\s+(?<experience>[0-9,]+)\s+Level:\s+(?<level>[0-9]+)]

      All = Regexp.union(Stat, Citizenship, NoCitizenship, Society, NoSociety, PSM, Skill, Spell, Levelup)

    end

    def self.parse(line)
      # O(1) vs O(N)
      return :noop unless line =~ Pattern::All
      begin
        case line
        when Pattern::Citizenship
          Infomon.set("citizenship", Regexp.last_match[:town])
          :ok
        when Pattern::NoCitizenship
          Infomon.set("citizenship", nil)
          :ok
        when Pattern::Stat
          match = Regexp.last_match

          Infomon.batch_set(
            ["stat.%s" % match[:stat], match[:value].to_i],
            ["stat.%s.bonus" % match[:stat], match[:bonus].to_i],
            ["stat.%s.enhanced" % match[:stat], match[:enhanced_value].to_i],
            ["stat.%s.enhanced.bonus" % match[:stat], match[:enhanced_bonus].to_i]
          )
          
          #Infomon.set("stat.%s" % match[:stat], match[:value].to_i)
          #Infomon.set("stat.%s.bonus" % match[:stat], match[:bonus].to_i)
          #Infomon.set("stat.%s.enhanced" % match[:stat], match[:enhanced_value].to_i)
          #Infomon.set("stat.%s.enhanced_bonus" % match[:stat], match[:enhanced_bonus].to_i)
          :ok
        when Pattern::Levelup
          match = Regexp.last_match
          Infomon.set("stat.%s" % match[:stat], match[:value].to_i)
          Infomon.set("stat.%s.bonus" % match[:stat], match[:bonus].to_i)
          :ok
        when Pattern::Society
          match = Regexp.last_match
          Infomon.set("society.status", match[:society])
          Infomon.set("society.rank", match[:rank])
          :ok
        when Pattern::NoSociety
          # todo: should this be nil?
          Infomon.set("society.status", "None")
          Infomon.set("society.rank", 0)
          :ok
        when Pattern::PSM
          match = Regexp.last_match
          Infomon.set("psm.%s" % match[:command], match[:ranks].to_i)
          :ok
        when Pattern::Skill
          # todo: is there a need for ranks?
          # todo: change Elemental Lore - Air to elair (and others)?
          match = Regexp.last_match
          Infomon.set("skill.%s" % match[:name], match[:bonus].to_i)
          :ok
        when Pattern::Spell
          # todo: capture SK item spells here?
          match = Regexp.last_match
          Infomon.set("spell.%s" % match[:name], match[:rank].to_i)
          :ok
        when Pattern::CharRaceProf
          # name captured here, but do not rely on it - use XML instead
          match = Regexp.last_match
          Infomon.set("stat.race", match[:race])
          Infomon.set("stat.profession", match[:profession])
          :ok
        when Pattern::CharGenderAgeExpLevel
          # level captured here, but do not rely on it - use XML instead
          match = Regexp.last_match
          Infomon.set("stat.gender", match[:gender])
          Infomon.set("stat.age", match[:age])
          Infomon.set("stat.experience", match[:experience])
          :ok
        else
          :noop
        end
      rescue => exception
        puts exception
      end
    end
  end
end
