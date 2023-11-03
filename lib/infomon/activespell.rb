module ActiveSpell
  #
  # Spell timing true-up (Invoker and SK item spells do not have proper durations)
  # this needs to be addressed in class Spell rewrite
  # in the meantime, this should mean no spell is more than 1 second off from
  # Simu's time calculations
  #

  def self.get_spell_info(spell_check = XMLData.active_spells)
    puts "spell update requested\r\n" if $infomon_debug
    update_spell_durations = spell_check
    update_spell_names = []
    makeychange = []
    update_spell_durations.each do |k, _v|
      case k
      when /(?:Mage Armor|520) - /
        makeychange << k
        update_spell_names.push('Mage Armor')
        next
      when /(?:CoS|712) - /
        makeychange << k
        update_spell_names.push('Cloak of Shadows')
        next
      when /Enh\./
        makeychange << k
        case k
        when /Enh\. Strength/
          update_spell_names.push('Surge of Strength')
        when /Enh\. (?:Dexterity|Agility)/
          update_spell_names.push('Burst of Swiftness')
        end
        next
      when /Empowered/
        makeychange << k
        update_spell_names.push('Shout')
        next
      when /Multi-Strike/
        makeychange << k
        update_spell_names.push('MStrike Cooldown')
        next
      when /Next Bounty Cooldown/
        makeychange << k
        update_spell_names.push('Next Bounty')
        next
      when /(?:Resist Nature|620) (?:- (?:Heat|Cold) \(\d\d%|- Steam \(\d\d|- Lightning|\(\d\d%\))/
        makeychange << k
        update_spell_names.push('Resist Nature')
        next
      end
      update_spell_names << k
    end
    makeychange.each do |changekey|
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
      when /(?:Resist Nature|620) (?:- (?:Heat|Cold) \(\d\d%|- Steam \(\d\d|- Lightning|\(\d\d%\))/
        update_spell_durations['Resist Nature'] = update_spell_durations.delete changekey
      end
    end
    [update_spell_names, update_spell_durations]
  end

  def self.update_spell_durations
    begin
      respond "[infomon] updating spell durations..." if $infomon_debug
      update_spell_names, update_spell_durations = ActiveSpell.get_spell_info
      puts "#{update_spell_names}\r\n" if $infomon_debug
      puts "#{update_spell_durations}\r\n" if $infomon_debug

      existing_spell_names = []
      ignore_spells = ["Berserk", "Council Task", "Council Punishment", "Briar Betrayer"]
      Spell.active.each { |s| existing_spell_names << s.name }
      inactive_spells = existing_spell_names - ignore_spells - update_spell_names
      inactive_spells.reject! do |s|
        s =~ /^Aspect of the \w+ Cooldown|^[\w\s]+ Recovery/
      end
      inactive_spells.each do |s|
        badspell = Spell[s].num
        Spell[badspell].putdown if Spell[s].active?
      end

      update_spell_durations.uniq.each do |k, v|
        if (spell = Spell.list.find { |s| (s.name.downcase == k.strip.downcase) || (s.num.to_s == k.strip) })
          if (spell.circle.to_i == 10) and not Spell.active.any? { |s| s.circle.to_i == 10 }
            Spellsong.renewed
          end
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
    rescue StandardError => e
      if $infomon_debug
        respond 'Error in spell durations thread'
        respond e.inspect
      end
    end
  end

  def self.request_update
    queue << Time.now
  end

  def self.queue
    @queue ||= Queue.new
  end

  def self.block_until_update_requested
    event = queue.pop
    queue.clear
    event
  end

  def self.watch!
    @thread ||= Thread.new do
      loop do
        block_until_update_requested
        update_spell_durations
      rescue StandardError => e
        respond 'Error in spell durations thread'
        respond e.inspect
      end
    end
  end
end
