class Spellsong
  def Spellsong.cost
    Spellsong.renew_cost
  end

  def Spellsong.tonisdodgebonus
    thresholds = [1, 2, 3, 5, 8, 10, 14, 17, 21, 26, 31, 36, 42, 49, 55, 63, 70, 78, 87, 96]
    bonus = 20
    thresholds.each { |val| if Skills.elair >= val then bonus += 1 end }
    bonus
  end

  def Spellsong.mirrorsdodgebonus
    20 + ((Spells.bard - 19) / 2).round
  end

  def Spellsong.mirrorscost
    [19 + ((Spells.bard - 19) / 5).truncate, 8 + ((Spells.bard - 19) / 10).truncate]
  end

  def Spellsong.sonicbonus
    (Spells.bard / 2).round
  end

  def Spellsong.sonicarmorbonus
    Spellsong.sonicbonus + 15
  end

  def Spellsong.sonicbladebonus
    Spellsong.sonicbonus + 10
  end

  def Spellsong.sonicweaponbonus
    Spellsong.sonicbladebonus
  end

  def Spellsong.sonicshieldbonus
    Spellsong.sonicbonus + 10
  end

  def Spellsong.valorbonus
    10 + (([Spells.bard, Stats.level].min - 10) / 2).round
  end

  def Spellsong.valorcost
    [10 + (Spellsong.valorbonus / 2), 3 + (Spellsong.valorbonus / 5)]
  end

  def Spellsong.luckcost
    [6 + ((Spells.bard - 6) / 4), (6 + ((Spells.bard - 6) / 4) / 2).round]
  end

  def Spellsong.manacost
    [18, 15]
  end

  def Spellsong.fortcost
    [3, 1]
  end

  def Spellsong.shieldcost
    [9, 4]
  end

  def Spellsong.weaponcost
    [12, 4]
  end

  def Spellsong.armorcost
    [14, 5]
  end

  def Spellsong.swordcost
    [25, 15]
  end
end
