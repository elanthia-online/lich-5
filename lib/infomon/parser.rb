# frozen_string_literal: true

module Infomon
  # this module handles all of the logic for parsing game lines that infomon depends on
  module Parser
    module Pattern
      # Regex patterns grouped for Info, Exp, Skill and PSM parsing - calls upsert_batch to reduce db impact
      CharRaceProf = /^Name:\s+(?<name>[A-z\s']+)\s+Race:\s+(?<race>[A-z]+|[A-z]+(?: |-)[A-z]+)\s+Profession:\s+(?<profession>[-A-z]+)/.freeze
      CharGenderAgeExpLevel = /^Gender:\s+(?<gender>[A-z]+)\s+Age:\s+(?<age>[,0-9]+)\s+Expr:\s+(?<experience>[0-9,]+)\s+Level:\s+(?<level>[0-9]+)/.freeze
      Stat = /^\s*(?<stat>[A-z]+)\s\((?:STR|CON|DEX|AGI|DIS|AUR|LOG|INT|WIS|INF)\):\s+(?<value>[0-9]+)\s\((?<bonus>-?[0-9]+)\)\s+[.]{3}\s+(?<enhanced_value>\d+)\s+\((?<enhanced_bonus>-?\d+)\)/.freeze
      StatEnd = /^Mana:\s+\d+\s+Silver:\s(?<silver>[\d,]+)$/.freeze
      Fame = /^\s+Level: \d+\s+Fame: (?<fame>[\d,]+)$/.freeze # serves as ExprStart
      RealExp = %r{^\s+Experience: [\d,]+\s+Field Exp: (?<fxp_current>[\d,]+)/(?<fxp_max>[\d,]+)$}.freeze
      AscExp = /^\s+Ascension Exp: (?<ascension_experience>[\d,]+)\s+Recent Deaths: [\d,]+$/.freeze
      TotalExp = /^\s+Total Exp: (?<total_experience>[\d,]+)\s+Death's Sting: \w+$/.freeze
      LTE = /^\s+Long-Term Exp: (?<long_term_experience>[\d,]+)\s+Deeds: (?<deeds>\d+)$/.freeze
      ExprEnd = /^\s+Exp (?:until lvl|to next TP): [\d,]+/.freeze
      SkillStart = /^\s\w+\s\(at level \d+\), your current skill bonuses and ranks/.freeze
      Skill = /^\s+(?<name>[[a-zA-Z]\s\-']+)\.+\|\s+(?<bonus>\d+)\s+(?<ranks>\d+)/.freeze
      Spell = /^\s+(?<name>[\w\s\-']+)\.+\|\s+(?<rank>\d+).*$/.freeze
      SkillEnd = /^Training Points: \d+ Phy \d+ Mnt/.freeze
      PSMStart = /^\w+, the following (?:Armor Specializations|Combat Maneuvers|Feats|Shield Specializations|Weapon Techniques) are available:$/.freeze
      PSM = /^\s+(?<name>[A-z\s\-']+)\s+(?<command>[a-z]+)\s+(?<ranks>\d)\/(?<max>\d).*$/.freeze
      PSMEnd = /^   Subcategory: all$/.freeze

      # Single / low impact - single db write
      Levelup = /^\s+(?<stat>\w+)\s+\(\w{3}\)\s+:\s+(?<value>\d+)\s+(?:\+1)\s+\.\.\.\s+(?<bonus>\d+)(?:\s+\+1)?$/.freeze
      SpellsSolo = /^(?<name>[\w\s]+)\.+(?<rank>\d+).*$/.freeze # from SPELL command
      Citizenship = /^You currently have .*? citizenship in (?<town>.*)\.$/.freeze
      NoCitizenship = /^You don't seem to have citizenship\./.freeze
      Society = /^\s+You are a (?<standing>Master|member) (?:in|of) the (?<society>Order of Voln|Council of Light|Guardians of Sunfist)(?: at (?:rank|step) (?<rank>[0-9]+))?\.$/.freeze
      NoSociety = /^\s+You are not a member of any society at this time./.freeze
      Warcries = /^\s+(?<name>(?:Bertrandt's Bellow|Yertie's Yowlp|Gerrelle's Growl|Seanette's Shout|Carn's Cry|Horland's Holler))$/.freeze
      NoWarcries = /^You must be an active member of the Warrior Guild to use this skill\.$/.freeze

      # TODO: refactor / streamline?
      SleepActive = /^Your mind goes completely blank\.$|^You close your eyes and slowly drift off to sleep\.$|^You slump to the ground and immediately fall asleep\.  You must have been exhausted!$/.freeze
      SleepNoActive = /^Your thoughts slowly come back to you as you find yourself lying on the ground\.  You must have been sleeping\.$|^You wake up from your slumber\.$|^You are awoken|^You awake/.freeze
      BindActive = /^An unseen force envelops you, restricting all movement\./.freeze
      BindNoActive = /^The restricting force that envelops you dissolves away\.|^You shake off the immobilization that was restricting your movements!/.freeze
      SilenceActive = /^A pall of silence settles over you\.|^The pall of silence settles more heavily over you\./.freeze
      SilenceNoActive = /^The pall of silence leaves you\./.freeze
      CalmActive = /^A calm washes over you\./.freeze
      CalmNoActive = /^You are enraged by .*? attack!|^The feeling of calm leaves you\./.freeze
      CutthroatActive = /slices deep into your vocal cords!$|^All you manage to do is cough up some blood\.$/.freeze
      CutthroatNoActive = /^\s*The horrible pain in your vocal cords subsides as you spit out the last of the blood clogging your throat\.$|^That tingles, but there are no head injuries to repair\.$/.freeze

      # Adding spell regexes.  These do not write to infomon.db, they are used by Spell, Spells and ActiveSpells.
      SpellUpMsgs = /^#{Games::Gemstone::Spell.upmsgs.join('$|^')}$/o.freeze
      SpellDnMsgs = /^#{Games::Gemstone::Spell.dnmsgs.join('$|^')}$/o.freeze

      All = Regexp.union(CharRaceProf, CharGenderAgeExpLevel, Stat, StatEnd, Fame, RealExp, AscExp, TotalExp, LTE,
                         ExprEnd, SkillStart, Skill, Spell, SkillEnd, PSMStart, PSM, PSMEnd, Levelup, SpellsSolo,
                         Citizenship, NoCitizenship, Society, NoSociety, SleepActive, SleepNoActive, BindActive,
                         BindNoActive, SilenceActive, SilenceNoActive, CalmActive, CalmNoActive, CutthroatActive,
                         CutthroatNoActive, Warcries, NoWarcries, SpellUpMsgs, SpellDnMsgs)
    end

    def self.parse(line)
      # O(1) vs O(N)
      return :noop unless line =~ Pattern::All

      begin
        case line
        # blob saves
        when Pattern::CharRaceProf
          # name captured here, but do not rely on it - use XML instead
          @stat_hold = []
          Infomon.mutex.lock
          match = Regexp.last_match
          @stat_hold.push(['stat.race', match[:race].to_s],
                          ['stat.profession', match[:profession].to_s])
          :ok
        when Pattern::CharGenderAgeExpLevel
          # level captured here, but do not rely on it - use XML instead
          match = Regexp.last_match
          @stat_hold.push(['stat.gender', match[:gender]],
                          ['stat.age', match[:age].delete(',').to_i],
                          ['stat.experience', match[:experience].delete(',').to_i])
          :ok
        when Pattern::Stat
          match = Regexp.last_match
          @stat_hold.push(['stat.%s' % match[:stat], match[:value].to_i],
                          ['stat.%s_bonus' % match[:stat], match[:bonus].to_i],
                          ['stat.%s.enhanced' % match[:stat], match[:enhanced_value].to_i],
                          ['stat.%s.enhanced_bonus' % match[:stat], match[:enhanced_bonus].to_i])
          :ok
        when Pattern::StatEnd
          match = Regexp.last_match
          @stat_hold.push(['stat.silver', match[:silver].delete(',').to_i])
          Infomon.upsert_batch(@stat_hold)
          Infomon.mutex.unlock
          :ok
        when Pattern::Fame # serves as ExprStart
          @expr_hold = []
          Infomon.mutex.lock
          match = Regexp.last_match
          @expr_hold.push(['experience.fame', match[:fame].delete(',').to_i])
          :ok
        when Pattern::RealExp
          match = Regexp.last_match
          @expr_hold.push(['experience.fxp_current', match[:fxp_current].delete(',').to_i],
                          ['experience.fxp_max', match[:fxp_max].delete(',').to_i])
          :ok
        when Pattern::AscExp
          match = Regexp.last_match
          @expr_hold.push(['experience.ascension_experience', match[:ascension_experience].delete(',').to_i])
          :ok
        when Pattern::TotalExp
          match = Regexp.last_match
          @expr_hold.push(['experience.total_experience', match[:total_experience].delete(',').to_i])
          :ok
        when Pattern::LTE
          match = Regexp.last_match
          @expr_hold.push(['experience.long_term_experience', match[:long_term_experience].delete(',').to_i],
                          ['experience.deeds', match[:deeds].to_i])
          :ok
        when Pattern::ExprEnd
          Infomon.upsert_batch(@expr_hold)
          Infomon.mutex.unlock
          :ok
        when Pattern::SkillStart
          @skills_hold = []
          Infomon.mutex.lock
          :ok
        when Pattern::Skill
          match = Regexp.last_match
          @skills_hold.push(['skill.%s' % match[:name].downcase, match[:ranks].to_i],
                            ['skill.%s_bonus' % match[:name], match[:bonus].to_i])
          :ok
        when Pattern::Spell
          match = Regexp.last_match
          @skills_hold.push(['spell.%s' % match[:name].downcase, match[:rank].to_i])
          :ok
        when Pattern::SkillEnd
          Infomon.upsert_batch(@skills_hold)
          Infomon.mutex.unlock
          :ok
        when Pattern::PSMStart
          @psm_hold = []
          Infomon.mutex.lock
          :ok
        when Pattern::PSM
          match = Regexp.last_match
          @psm_hold.push(['psm.%s' % match[:command], match[:ranks].to_i])
          :ok
        when Pattern::PSMEnd
          Infomon.upsert_batch(@psm_hold)
          Infomon.mutex.unlock
          :ok
        when Pattern::NoWarcries
          Infomon.upsert_batch([['psm.bertrandts_bellow', 0],
                                ['psm.yerties_yowlp', 0],
                                ['psm.gerrelles_growl', 0],
                                ['psm.seanettes_shout', 0],
                                ['psm.carns_cry', 0],
                                ['psm.horlands_holler', 0]])
          :ok
        # end of blob saves
        when Pattern::Warcries
          match = Regexp.last_match
          Infomon.set('psm.%s' % match[:name].split(' ')[1], 1)
          :ok
        when Pattern::Levelup
          match = Regexp.last_match
          Infomon.upsert_batch([['stat.%s' % match[:stat], match[:value].to_i],
                                ['stat.%s_bonus' % match[:stat], match[:bonus].to_i]])
          :ok
        when Pattern::SpellsSolo
          match = Regexp.last_match
          Infomon.set('spell.%s' % match[:name].downcase, match[:rank].to_i)
          :ok
        when Pattern::Citizenship
          Infomon.set('citizenship', Regexp.last_match[:town])
          :ok
        when Pattern::NoCitizenship
          Infomon.set('citizenship', 'None')
          :ok
        when Pattern::Society
          match = Regexp.last_match
          Infomon.set('society.status', match[:society])
          Infomon.set('society.rank', match[:rank])
          case match[:standing] # if Master in society the rank match is nil
          when 'Master'
            if /Voln/.match?(match[:society])
              Infomon.set('society.rank', 26)
            elsif /Council of Light|Guardians of Sunfist/.match?(match[:society])
              Infomon.set('society.rank', 20)
            end
          end
          :ok
        when Pattern::NoSociety
          Infomon.set('society.status', 'None')
          Infomon.set('society.rank', 0)
          :ok
        # TODO: refactor / streamline?
        when Pattern::SleepActive
          Infomon.set('status.sleeping', true)
          :ok
        when Pattern::SleepNoActive
          Infomon.set('status.sleeping', false)
          :ok
        when Pattern::BindActive
          Infomon.set('status.bound', true)
          :ok
        when Pattern::BindNoActive
          Infomon.set('status.bound', false)
          :ok
        when Pattern::SilenceActive
          Infomon.set('status.silenced', true)
          :ok
        when Pattern::SilenceNoActive
          Infomon.set('status.silenced', false)
          :ok
        when Pattern::CalmActive
          Infomon.set('status.calmed', true)
          :ok
        when Pattern::CalmNoActive
          Infomon.set('status.calmed', false)
          :ok
        when Pattern::CutthroatActive
          Infomon.set('status.cutthroat', true)
          :ok
        when Pattern::CutthroatNoActive
          Infomon.set('status.cutthroat', false)
          :ok
        when Pattern::SpellUpMsgs
          spell = Spell.list.find do |s|
            line =~ /^#{s.msgup}$/
          end
          spell.putup unless spell.active?
          # add various cooldowns back without affecting parse speed
          Spells.require_cooldown(spell)
          :ok
        when Pattern::SpellDnMsgs
          spell = Spell.list.find do |s|
            line =~ /^#{s.msgdn}$/
          end
          spell.putdown if spell.active?
          :ok
        else
          :noop
        end
      rescue StandardError => e
        puts e
      end
    end
  end
end
