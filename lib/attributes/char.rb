# carve out supporting infomon move to lib

class Char
  def Char.init(_blah)
    echo 'Char.init is no longer used. Update or fix your script.'
  end

  def Char.name
    XMLData.name
  end

  def Char.stance(*args)
    checkstance(*args)
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

  def Char.respond_to?(m, *args)
    [Stats, Skills, Spellsong].any? { |k| k.respond_to?(m) } or super(m, *args)
  end

  def Char.method_missing(meth, *args)
    polyfill = [Stats, Skills, Spellsong].find { |klass|
      klass.respond_to?(meth, *args)
    }
    return polyfill.send(meth, *args) if polyfill
    super(meth, *args)
  end

  def Char.info
    echo "Char.info is no longer supported. Update or fix your script."
  end

  def Char.skills
    echo "Char.skills is no longer supported. Update or fix your script."
  end

  def Char.citizenship
    Infomon.get('citizenship') if XMLData.game =~ /GS/
  end

  def Char.citizenship=(_val)
    echo "Updating via Char.citizenship is no longer supported. Update or fix your script."
  end
end
