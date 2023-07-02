# carve out supporting infomon move to lib

class Char
  def Char.init(_blah)
    echo 'Char.init is no longer used. Update or fix your script.'
  end

  def Char.name
    XMLData.name
  end

  def Char.health(*args)
    checkhealth(*args)
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

  def Char.dump_info
    echo "Char.dump_info is no longer used. Update or fix your script."
  end

  def Char.load_info(_string)
    echo "Char.load_info is no longer used. Update or fix your script."
  end

  def Char.method_missing(meth, *args)
    # Deprecated klass Society
    [Stats, Skills, Spellsong].each { |klass|
      begin
        result = klass.__send__(meth, *args)
        return result
      rescue
        nil
      end
    }
    respond 'missing method: ' + meth
    raise NoMethodError
  end

  def Char.info
=begin
  Deprecated info request format
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
=end
    echo "Char.info is no longer supported. Update or fix your script."
  end

  def Char.skills
=begin
  Deprecated skills request format
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
=end
    echo "Char.skills is no longer supported. Update or fix your script."
  end

  def Char.citizenship
    Infomon.get('citizenship') if XMLData.game =~ /GS/
  end

  def Char.citizenship=(_val)
    echo "Updating via Char.citizenship is no longer supported. Update or fix your script."
  end
end
