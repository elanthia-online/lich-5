module Infomon
  # this module handles all of the logic for parsing game lines that infomon depends on
  module Parser
    module Pattern
      Stat = %r[^\s*(?<stat>[A-z]+)\s\((?:STR|CON|DEX|AGI|DIS|AUR|LOG|INT|WIS|INF)\):\s+(?<value>[0-9]+)\s\((?<bonus>-?[0-9]+)\)\s+[.]{3}\s+(?<enhanced_value>\d+)\s+\((?<enhanced_bonus>-?\d+)\)]
      Citizenship = /^You currently have .*? citizenship in (?<town>.*)\.$/
      NoCitizenship = /You don't seem to have citizenship\./
      Society = /^\s+You are a (?:Master|member) (?:in|of) the (?<society>Order of Voln|Council of Light|Guardians of Sunfist)(?: at rank (?<rank>[0-9]+)| at step (?<rank>[0-9]+))?\.$/
      NoSociety = %r[^\s+You are not a member of any society at this time.]
      PSM = %r[^\s+(?<name>[\w\s\-']+)\s+(?<command>[a-z]+)\s+(?<ranks>\d)\/(?<max>\d)\s+]
      Skill = %r[^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<bonus>\d+)\s+(?<ranks>\d+)]
      Spell = %r[^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<rank>\d+)$|^(?<name>[\w\s\-']+)\.+(?<rank>\d+)$]
      Levelup = %r[^\s+(?<stat>\w+)\s+\(\w{3}\)\s+:\s+(?<value>\d+)\s+(?:\+1)\s+\.\.\.\s+(?<bonus>\d+)(?:\s+\+1)?$]
      Fame = %r[^\s+Level: \d+\s+Fame: (?<fame>[\d,]+)$]
      RealExp = %r[^\s+Experience: (?<experience>[\d,]+)\s+Field Exp: (?<fxp_current>[\d,]+)/(?<fxp_max>[\d,]+)$]
      AscExp = %r[^\s+Ascension Exp: (?<ascension_experience>[\d,]+)\s+Recent Deaths: [\d,]+$]
      TotalExp = %r[^\s+Total Exp: (?<total_experience>[\d,]+)\s+Death's Sting: [\w]+$]
      LTE = %r[^\s+Long-Term Exp: (?<long_term_experience>[\d,]+)\s+Deeds: (?<deeds>\d+)$]
      TNL = %r[^\s+Exp until lvl: (?<experience_to_next_level>[\d,]+)(?:\s+Exp to next ATP: [\d,]+)?$]

      All = Regexp.union(Stat, Citizenship, NoCitizenship, Society, NoSociety, PSM, Skill, Spell, Levelup, Fame, RealExp, AscExp, TotalExp, LTE, TNL)
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
        when Pattern::Fame
          match = Regexp.last_match
          Infomon.set("stat.fame", match[:fame].gsub(',', '').to_i)
          :ok
        when Pattern::RealExp
          match = Regexp.last_match
          Infomon.set("stat.experience", match[:experience].gsub(',', '').to_i)
          Infomon.set("stat.fxp_current", match[:fxp_current].gsub(',', '').to_i)
          Infomon.set("stat.fxp_max", match[:fxp_max].gsub(',', '').to_i)
          :ok
        when Pattern::AscExp
          match = Regexp.last_match
          Infomon.set("stat.ascension_experience", match[:ascension_experience].gsub(',', '').to_i)
          :ok
        when Pattern::TotalExp
          match = Regexp.last_match
          Infomon.set("stat.total_experience", match[:total_experience].gsub(',', '').to_i)
          :ok
        when Pattern::LTE
          match = Regexp.last_match
          Infomon.set("stat.long_term_experience", match[:long_term_experience].gsub(',', '').to_i)
          Infomon.set("stat.deeds", match[:deeds].to_i)
          :ok
        when Pattern::TNL
          match = Regexp.last_match
          Infomon.set("stat.experience_to_next_level", match[:experience_to_next_level].gsub(',', '').to_i)
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
