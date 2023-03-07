# frozen_string_literal: true

module Lich
  #  module Util
  module Statsinfo
    ## this is called from infomon, to prepare for infomon move to library
    ## loads when explicitly requested

    def self.request(type = 'info', params)
      working_capital = params
      case type
      when /levelup/
        _respond 'Landed in levelup' if $infomon_debug
        levelup(working_capital)
      when /info/
        _respond 'Landed in info' if $infomon_debug
        update_info(working_capital)
      when /skills/
        _respond 'Landed in skills' if $infomon_debug
        update_skills(working_capital)
      when /psms/
        _respond 'Landed in psms' if $infomon_debug
        response = Lich::Util.quiet_command_xml("#{working_capital} info", /<a exist=.+#{Char.name}/, timeout: 0.5)
        update_psms(response)
      else
        _respond 'This is where I do NOT want to be!'
      end
    end

    def self.update_info(info_sent)
      info_sent_ary = info_sent.split(/\n/)
      info_sent_ary.each do |line|
        case line
        when /^Name:\s+[-A-z\s']+Race:\s+([-A-z\s]+)\s+Profession:\s+([-A-z\s]+)/
          Stats.race = ::Regexp.last_match(1).strip
          Stats.prof = ::Regexp.last_match(2).strip
        when /Gender:\s+([A-z]+)\s+Age:\s+([0-9]+)\s+Expr:\s+([0-9,]+)\s+Level:\s+([0-9]+)/
          Stats.gender = ::Regexp.last_match(1)
          Stats.age = ::Regexp.last_match(2).to_i
          Stats.exp = ::Regexp.last_match(3).to_i
          Stats.level = ::Regexp.last_match(4).to_i
        when /^\s*[A-Z][a-z]+\s\((STR|CON|DEX|AGI|DIS|AUR|LOG|INT|WIS|INF)\):\s+([0-9]+)\s\((-?[0-9]+)\)\s+[.]{3}\s+(\d+)\s+\((-?\d+)\)/
          Stats.send("#{::Regexp.last_match(1).downcase}=",
                     [::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i])
          begin
            Stats.send("enhanced_#{::Regexp.last_match(1).downcase}=",
                       [::Regexp.last_match(4).to_i, ::Regexp.last_match(5).to_i])
          rescue StandardError
            nil
          end
        end
      end
      $infomon_values['Stats'] = Stats.serialize
      respond $infomon_values if $infomon_debug
    end

    def self.update_skills(skills_sent)
      skills_sent_ary = skills_sent.split(/\n/)
      skills_sent_ary.each do |line|
        next line unless line =~ /\.+/

        skill_check = line.gsub(/[^A-Za-z]/, '').downcase
        if skill_check =~ /minorelemental|minormental|majorelemental|minorspiritual|majorspiritual|wizard|sorcerer|ranger|paladin|empath|cleric|bard/
          Spells.send("#{skill_check}=", line.scan(/[0-9]+/).first.to_i)
        else
          case skill_check
          when /elementalmanacontrol/
            skill_check = 'emc'
          when /spiritmanacontrol/
            skill_check = 'smc'
          when /mentalmanacontrol/
            skill_check = 'mmc'
          when /elementallore/
            skill_check = skill_check.gsub(/elementallore/, 'el')
          when /spirituallore/
            skill_check = skill_check.gsub(/spirituallore/, 'sl')
          when /sorcerouslore/
            skill_check = skill_check.gsub(/sorcerouslore/, 'sl')
          when /mentallore/
            skill_check = skill_check.gsub(/mentallore/, 'ml')
          end
          Skills.send("#{skill_check}=", line.scan(/[0-9]+/).first.to_i)
        end
      end
      $infomon_values['Skills'] = Skills.serialize
      $infomon_values['Spells'] = Spells.serialize
    end

    def self.update_psms(psms_sent)
      psm_good_names = {
        'grapple_specializati' => 'grapple_specialization',
        'rolling_krynch_stanc' => 'rolling_krynch_stance',
        'stance_of_the_mongoo' => 'stance_of_the_mongoose',
        'weapon_specializatio' => 'weapon_specialization',
        'shield_strike_master' => 'shield_strike_mastery',
        'chain_armor_proficie' => 'chain_armor_proficiency',
        'light_armor_proficie' => 'light_armor_proficiency',
        'plate_armor_proficie' => 'plate_armor_proficiency',
        'scale_armor_proficie' => 'scale_armor_proficiency'
      }
      psms_sent.each do |line|
        case line
        when /your (Combat|Armor|Feat|Shield|Weapon).*? are as follows:/
          @psm_category = ::Regexp.last_match(1).dup
          echo @psm_category if $infomon_debug
          @psm_category = 'CMan' if @psm_category == 'Combat'
          $infomon_values[@psm_category.to_s.downcase] = {}
        when %r{^\s+([A-z\s']+)\s+<d cmd.+'>([a-z0-9]+)</d>\s+(\d)/(\d).*?$}
          _mnemonic_psm = ::Regexp.last_match(2)
          rank_psm = ::Regexp.last_match(3)
          _total_rank_psm = ::Regexp.last_match(4)
          name_psm = ::Regexp.last_match(1).strip.downcase.gsub(/[\s-]/, '_').gsub("'", '')
          name_psm = psm_good_names[name_psm] if psm_good_names.key?(name_psm)
          echo @psm_category if $infomon_debug
          echo name_psm if $infomon_debug
          echo rank_psm.to_i if $infomon_debug
          $infomon_values[@psm_category.to_s.downcase][name_psm] = rank_psm.to_i
          begin
            eval(@psm_category.to_s)[name_psm] = rank_psm
          rescue StandardError
            nil
          end
        else
          next line
        end
      end
    end

    def self.levelup(stats_sent)
      stats_sent_ary = stats_sent.split(/\n/)
      stats_sent_ary.each do |line|
        case line
        when /^are now level ([0-9]+)/
          Stats.level = ::Regexp.last_match(1).to_i
        when /^\s*(?:Strength|Constitution|Dexterity|Agility|Discipline|Aura|Logic|Intuition|Wisdom|Influence|Dexterity)\s+\((STR|CON|DEX|AGI|DIS|AUR|LOG|INT|WIS|INF)\)\s*:\s+([0-9]+)\s+\+([0-9]+)\s+\.\.\.\s+(-?[0-9]+)\s*\+?([0-9]+)\s*$/
          Stats.send("#{::Regexp.last_match(1).downcase}=",
                     [::Regexp.last_match(2).to_i + ::Regexp.last_match(3).to_i,
                      ::Regexp.last_match(4).to_i + ::Regexp.last_match(5).to_i])
        else
          next line
        end
      end
      $infomon_values['Stats'] = Stats.serialize
    end

    respond $infomon_values if $infomon_debug
  end
  # end # Util
end
