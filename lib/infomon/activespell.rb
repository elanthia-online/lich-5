module ActiveSpell
  #
  # Spell timing true-up (Invoker and SK item spells do not have proper durations)
  # this needs to be addressed in class Spell rewrite
  # in the meantime, this should mean no spell is more than 1 second off from
  # Simu's time calculations
  #
  unless Gem::Version.new(LICH_VERSION) < Gem::Version.new('5.0.16')
    loop do
      begin
        sleep 0.01 until $process_legacy_spell_durations
        update_spell_durations = ::XMLData.active_spells
        update_spell_names = []
        @makeychange = []
        update_spell_durations.each do |k, _v|
          case k
          when /(?:Mage Armor|520) - /
            @makeychange << k
            update_spell_names.push('Mage Armor')
            next
          when /(?:CoS|712) - /
            @makeychange << k
            update_spell_names.push('Cloak of Shadows')
            next
          when /Enh\./
            @makeychange << k
            case k
            when /Enh\. Strength/
              update_spell_names.push('Surge of Strength')
            when /Enh\. (?:Dexterity|Agility)/
              update_spell_names.push('Burst of Swiftness')
            end
            next
          when /Empowered/
            @makeychange << k
            update_spell_names.push('Shout')
            next
          when /Multi-Strike/
            @makeychange << k
            update_spell_names.push('MStrike Cooldown')
            next
          when /Next Bounty Cooldown/
            @makeychange << k
            update_spell_names.push('Next Bounty')
            next
          end
          update_spell_names << k
        end
        @makeychange.each do |changekey|
          next unless update_spell_durations.key?(changekey)

          case changekey
          when /(?:Mage Armor|520) - /
            update_spell_durations['Mage Armor'] = update_spell_durations.delete changekey
          when /(?:CoS|712) - /
            update_spell_durations['Cloak of Shadows'] = update_spell_durations.delete changekey
          when /Enh\. Strength/
            update_spell_durations['Surge of Strength'] = update_spell_durations.delete changekey
          when /Enh\. (?:Dexterity|Agility)/
            update_spell_durations['Burst of Swiftness'] = update_spell_durations.delete changekey
          when /Empowered/
            update_spell_durations['Shout'] = update_spell_durations.delete changekey
          when /Multi-Strike/
            update_spell_durations['MStrike Cooldown'] = update_spell_durations.delete changekey
          when /Next Bounty Cooldown/
            update_spell_durations['Next Bounty'] = update_spell_durations.delete changekey
          when /Next Group Bounty Cooldown/
            update_spell_durations['Next Group Bounty'] = update_spell_durations.delete changekey
          end
        end

        existing_spell_names = []
        ignore_spells = ['Berserk']
        Spell.active.each { |s| existing_spell_names << s.name }
        inactive_spells = existing_spell_names - ignore_spells - update_spell_names
        inactive_spells.each do |s|
          badspell = Spell[s].num
          Spell[badspell].putdown if Spell[s].active?
        end

        update_spell_durations.uniq.each do |k, v|
          if (spell = Spell.list.find { |s| (s.name.downcase == k.strip.downcase) || (s.num.to_s == k.strip) })
            spell.active = true
            spell.timeleft = if v - Time.now > 300 * 60
                               600.01
                             else
                               ((v - Time.now) / 60)
                             end
          elsif $infomon_debug
            respond "no spell matches #{k}"
          end
        end
      rescue StandardError
        respond 'Error in spell durations thread' if $infomon_debug
      end
      $process_legacy_spell_durations = false
    end
  end
end
