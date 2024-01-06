# carve out supporting infomon move to lib

class Char
  def Char.init(_blah)
    echo 'Char.init is no longer used. Update or fix your script.'
  end

  def Char.name
    XMLData.name
  end

  def Char.stance(num = nil)
    if num.nil?
      XMLData.stance_text
    elsif (num.class == String) and (num.to_i == 0)
      if num =~ /off/i
        XMLData.stance_value == 0
      elsif num =~ /adv/i
        XMLData.stance_value.between?(01, 20)
      elsif num =~ /for/i
        XMLData.stance_value.between?(21, 40)
      elsif num =~ /neu/i
        XMLData.stance_value.between?(41, 60)
      elsif num =~ /gua/i
        XMLData.stance_value.between?(61, 80)
      elsif num =~ /def/i
        XMLData.stance_value == 100
      else
        echo "Char.stance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
        nil
      end
    elsif (num.class == Integer) or (num =~ /^[0-9]+$/ and (num = num.to_i))
      XMLData.stance_value == num.to_i
    else
      echo "Char.stance: invalid argument (#{num}).  Must be off/adv/for/neu/gua/def or 0-100"
      nil
    end
  end

  def Char.health(num = nil)
    if num.nil?
      XMLData.health
    else
      XMLData.health >= num.to_i
    end
  end

  def Char.mana(num = nil)
    if num.nil?
      XMLData.mana
    else
      XMLData.mana >= num.to_i
    end
  end

  def Char.spirit(num = nil)
    if num.nil?
      XMLData.spirit
    else
      XMLData.spirit >= num.to_i
    end
  end

  def Char.stamina(num = nil)
    if num.nil?
      XMLData.stamina
    else
      XMLData.stamina >= num.to_i
    end
  end

  def Char.maxhealth
    Object.module_eval { XMLData.max_health }
  end

  def Char.maxmana
    Object.module_eval { XMLData.max_mana }
  end

  def Char.maxspirit
    Object.module_eval { XMLData.max_spirit }
  end

  def Char.maxstamina
    Object.module_eval { XMLData.max_stamina }
  end

  def Char.percenthealth(num = nil)
    if num.nil?
      ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i
    else
      ((XMLData.health.to_f / XMLData.max_health.to_f) * 100).to_i >= num.to_i
    end
  end

  def Char.percentmana(num = nil)
    if XMLData.max_mana == 0
      percent = 100
    else
      percent = ((XMLData.mana.to_f / XMLData.max_mana.to_f) * 100).to_i
    end
    if num.nil?
      percent
    else
      percent >= num.to_i
    end
  end

  def Char.percentspirit(num = nil)
    if num.nil?
      ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i
    else
      ((XMLData.spirit.to_f / XMLData.max_spirit.to_f) * 100).to_i >= num.to_i
    end
  end

  def Char.percentstamina(num = nil)
    if XMLData.max_stamina == 0
      percent = 100
    else
      percent = ((XMLData.stamina.to_f / XMLData.max_stamina.to_f) * 100).to_i
    end
    if num.nil?
      percent
    else
      percent >= num.to_i
    end
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
