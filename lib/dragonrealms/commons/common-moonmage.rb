module DRCMM
  module_function

  def observe(thing)
    output = "observe #{thing} in heavens"
    output = 'observe heavens' if thing.eql?('heavens')
    DRC.bput(output.to_s, 'Your search for', 'You see nothing regarding the future', 'Clouds obscure', 'Roundtime', 'The following heavenly bodies are visible:', "That's a bit hard to do while inside")
  end

  def predict(thing)
    output = "predict #{thing}"
    output = 'predict state all' if thing.eql?('all')
    DRC.bput(output.to_s, 'You predict that', 'You are far too', 'you lack the skill to grasp them fully', /(R|r)oundtime/i, 'You focus inwardly')
  end

  def study_sky
    DRC.bput('study sky', 'You feel a lingering sense', 'You feel it is too soon', 'Roundtime', 'You are unable to sense additional information', 'detect any portents')
  end

  def get_telescope?(telescope_name = 'telescope', storage)
    return true if DRCI.in_hands?(telescope_name)

    if storage['tied']
      DRCI.untie_item?(telescope_name, storage['tied'])
    elsif storage['container']
      unless DRCI.get_item?(telescope_name, storage['container'])
        echo("Telescope not found in container. Trying to get it from anywhere we can.")
        return DRCI.get_item?(telescope_name)
      end
      true
    else
      return DRCI.get_item?(telescope_name)
    end
  end

  def store_telescope?(telescope_name = "telescope", storage)
    return true unless DRCI.in_hands?(telescope_name)

    if storage['tied']
      DRCI.tie_item?(telescope_name, storage['tied'])
    elsif storage['container']
      DRCI.put_away_item?(telescope_name, storage['container'])
    else
      DRCI.put_away_item?(telescope_name)
    end
  end

  def get_telescope(storage)
    if storage['tied']
      DRC.bput("untie telescope from my #{storage['tied']}", 'You remove', 'You untie', '^What were you referring', 'Untie what', '^You are a little too busy')
    elsif storage['container']
      DRC.bput("get telescope in my #{storage['container']}", 'You get a', 'You are already', "That can't be picked up", 'You need a free hand to pick that up.', 'What were you referring to', 'stop practicing your Athletics')
    else
      DRC.bput('get my telescope', 'You get a', 'What were you referring to', 'You are already holding that.', "That can't be picked up", 'You need a free hand to pick that up.', 'stop practicing your Athletics')
    end
  end

  def store_telescope(storage)
    if storage['tied']
      DRC.bput("tie telescope to my #{storage['tied']}", 'You attach', 'you tie', 'You are a little too busy')
    elsif storage['container']
      DRC.bput("put telescope in my #{storage['container']}", 'You put')
    else
      DRC.bput('stow my telescope', 'Stow what', 'You put your telescope')
    end
  end

  def peer_telescope
    DRC.bput('peer my telescope',
             'The pain is too much',
             'You see nothing regarding the future',
             "You believe you've learned all that you can about",
             get_data('constellations').observe_finished_messages,
             'open it',
             'Your vision is too fuzzy',
             'Roundtime')
  end

  def center_telescope(target)
    case DRC.bput("center telescope on #{target}",
                  'Center what',
                  'You put your eye',
                  'open it to make any use of it',
                  'The pain is too much',
                  "That's a bit tough to do when you can't see the sky",
                  "You would probably need a periscope to do that",
                  'Your search for',
                  'Your vision is too fuzzy',
                  "You'll need to open it to make any use of it",
                  'You must have both hands free')
    when 'The pain is too much', "That's a bit tough to do when you can't see the sky"
      echo("Planet #{target} not visible. Are you indoors perhaps?")
    when "You'll need to open it to make any use of it"
      fput("open my telescope")
      fput("center telescope on #{target}")
    end
  end

  def align(skill)
    DRC.bput("align #{skill}", 'You focus internally')
  end

  def get_bones?(storage)
    if storage['tied']
      DRCI.untie_item?("bones", storage['tied'])
    elsif storage['container']
      DRCI.get_item?("bones", storage['container'])
    else
      DRCI.get_item?("bones")
    end
  end

  def store_bones?(storage)
    if storage['tied']
      DRCI.tie_item?("bones", storage['tied'])
    elsif storage['container']
      DRCI.put_away_item?("bones", storage['container'])
    else
      DRCI.put_away_item?("bones")
    end
  end

  def get_bones(storage)
    if storage['tied']
      DRC.bput("untie bones from my #{storage['container']}", 'You untie', 'You remove')
    else
      DRC.bput("get bones from my #{storage['container']}", 'You get')
    end
  end

  def store_bones(storage)
    if storage['tied']
      DRC.bput("tie bones to my #{storage['container']}", 'You attach', 'You tie')
    else
      DRC.bput("put bones in my #{storage['container']}", 'You put')
    end
  end

  def roll_bones(storage)
    get_bones(storage)

    DRC.bput('roll my bones', 'roundtime')
    waitrt?

    store_bones(storage)
  end

  def get_div_tool?(tool)
    if tool['tied']
      DRCI.untie_item?(tool['name'], tool['container'])
    elsif tool['worn']
      DRCI.remove_item?(tool['name'])
    else
      DRCI.get_item?(tool['name'], tool['container'])
    end
  end

  def store_div_tool?(tool)
    if tool['tied']
      DRCI.tie_item?(tool['name'], tool['container'])
    elsif tool['worn']
      DRCI.wear_item?(tool['name'])
    else
      DRCI.put_away_item?(tool['name'], tool['container'])
    end
  end

  def get_div_tool(tool)
    if tool['tied']
      DRC.bput("untie #{tool['name']} from my #{tool['container']}", tool['name'])
    elsif tool['worn']
      DRC.bput("remove my #{tool['name']}", tool['name'])
    else
      DRC.bput("get my #{tool['name']} from my #{tool['container']}", tool['name'], 'you get')
    end
  end

  def store_div_tool(tool)
    if tool['tied']
      DRC.bput("tie #{tool['name']} to my #{tool['container']}", tool['name'])
    elsif tool['worn']
      DRC.bput("wear my #{tool['name']}", tool['name'])
    else
      DRC.bput("put #{tool['name']} in my #{tool['container']}", tool['name'], 'You put')
    end
  end

  def use_div_tool(tool_storage)
    get_div_tool(tool_storage)

    {
      'charts' => 'review',
      'bones'  => 'roll',
      'mirror' => 'gaze',
      'bowl'   => 'gaze',
      'prism'  => 'raise'
    }.select { |tool, _| tool_storage['name'].include?(tool) }
      .each   { |tool, verb| DRC.bput("#{verb} my #{tool}", 'roundtime'); waitrt? }

    store_div_tool(tool_storage)
  end

  # There are many variants of a summoned moon weapon (blade, staff, sword, etc)
  # This function checks if you're holding one then tries to wear it.
  # Returns true if what is in your hands is a summoned moon weapon that becomes worn.
  # Returns false if you're not holding a moon weapon, or you are but can't wear it.
  # https://elanthipedia.play.net/Shape_Moonblade
  def wear_moon_weapon?
    moon_wear_messages = ["You're already", "You can't wear", "Wear what", "telekinetic"]
    wore_it = false
    if is_moon_weapon?(DRC.left_hand)
      wore_it = wore_it || DRC.bput("wear #{DRC.left_hand}", *moon_wear_messages) == "telekinetic"
    end
    if is_moon_weapon?(DRC.right_hand)
      wore_it = wore_it || DRC.bput("wear #{DRC.right_hand}", *moon_wear_messages) == "telekinetic"
    end
    return wore_it
  end

  # Drops the moon weapon in your hands, if any.
  # Returns true if dropped something, false otherwise.
  def drop_moon_weapon?
    moon_drop_messages = ["As you open your hand", "What were you referring to"]
    dropped_it = false
    if is_moon_weapon?(DRC.left_hand)
      dropped_it = dropped_it || DRC.bput("drop #{DRC.left_hand}", *moon_drop_messages) == "As you open your hand"
    end
    if is_moon_weapon?(DRC.right_hand)
      dropped_it = dropped_it || DRC.bput("drop #{DRC.right_hand}", *moon_drop_messages) == "As you open your hand"
    end
    return dropped_it
  end

  # Is a moon weapon in your hands?
  def holding_moon_weapon?
    return is_moon_weapon?(DRC.left_hand) || is_moon_weapon?(DRC.right_hand)
  end

  # Try to hold a moon weapon.
  # If you end up not holding a moon weapon then returns false.
  def hold_moon_weapon?
    return true if holding_moon_weapon?
    return false if [DRC.left_hand, DRC.right_hand].compact.length >= 2

    ['moonblade', 'moonstaff'].each do |weapon|
      glance = DRC.bput("glance my #{weapon}", "You glance at a .* #{weapon}", "I could not find")
      case glance
      when /You glance/
        return DRC.bput("hold my #{weapon}", "You grab", "You aren't wearing", "Hold hands with whom?", "You need a free hand") == "You grab"
      end
    end
    false
  end

  # Does the item appear to be a moon weapon?
  def is_moon_weapon?(item)
    return false unless item

    !(item =~ /^((black|red-hot|blue-white) moon(blade|staff))$/i).nil?
  end

  def moon_used_to_summon_weapon
    # Note, if you have more than one weapon summoned at a time
    # then the results of this method are non-deterministic.
    # For example, if you have 2+ moonblades/staffs cast on different moons.
    ['moonblade', 'moonstaff'].each do |weapon|
      glance = DRC.bput("glance my #{weapon}", "You glance at a .* (black|red-hot|blue-white) moon(blade|staff)", "I could not find")
      case glance
      when /black moon/
        return 'katamba'
      when /red-hot moon/
        return 'yavash'
      when /blue-white moon/
        return 'xibar'
      end
    end
    return nil
  end

  ## Migrating prediction/planet/moon defs from common-arcana to here.
  # Delete this line, and the defs from common-arcana after they've been
  # merged here and things look good.

  def update_astral_data(data, settings = nil)
    if data['moon']
      data = set_moon_data(data)
    elsif data['stats']
      data = set_planet_data(data, settings)
    end
    data
  end

  def find_visible_planets(planets, settings = nil)
    unless get_telescope?(settings.telescope_name, settings.telescope_storage)
      DRC.message("Coult not get telescope to find visible planets")
      return
    end

    Flags.add('planet-not-visible', 'turns up fruitless')
    observed_planets = []

    planets.each do |planet|
      center_telescope(planet)
      observed_planets << planet unless Flags['planet-not-visible']
      Flags.reset('planet-not-visible')
    end

    Flags.delete('planet-not-visible')
    DRC.message("Could not store telescope after finding visible planets") unless store_telescope?(settings.telescope_name, settings.telescope_storage)
    observed_planets
  end

  def set_planet_data(data, settings = nil)
    return data unless data['stats']

    planets = get_data('constellations')[:constellations].select { |planet| planet['stats'] }
    planet_names = planets.map { |planet| planet['name'] }
    visible_planets = find_visible_planets(planet_names, settings)
    data['stats'].each do |stat|
      cast_on = planets.map { |planet| planet['name'] if planet['stats'].include?(stat) && visible_planets.include?(planet['name']) }.compact.first
      next unless cast_on

      data['cast'] = "cast #{cast_on}"
      return data
    end
    DRC.message("Could not set planet data. Cannot cast #{data['abbrev']}")
  end

  def set_moon_data(data)
    return data unless data['moon']

    moon = visible_moons.first
    if moon
      data['cast'] = "cast #{moon}"
    elsif !moon && data['name'].downcase == 'cage of light'
      data['cast'] = "cast ambient"
    else
      echo "No moon available to cast #{data['name']}"
      data = nil
    end
    data
  end

  # returns true if at least one bright moon (yavash, xibar) or the sun are
  #  above the horizon and won't set for at least another ~4 minutes.
  def bright_celestial_object?
    check_moonwatch
    (UserVars.sun['day'] && UserVars.sun['timer'] >= 4) || visible_moons.include?('xibar') || visible_moons.include?('yavash')
  end

  # returns true if at least one moon (katamba, yavash, xibar) or the sun are
  #  above the horizon and won't set for at least another ~4 minutes.
  def any_celestial_object?
    check_moonwatch
    (UserVars.sun['day'] && UserVars.sun['timer'] >= 4) || moons_visible?
  end

  # Returns true if at least one moon (e.g. katamba, yavash, xibar)
  # is above the horizon and won't set for at least another ~4 minutes.
  def moons_visible?
    !visible_moons.empty?
  end

  # Returns list of moon names (e.g. katamba, yavash, xibar)
  # that are above the horizon and won't set for at least another ~4 minutes.
  def visible_moons
    check_moonwatch
    UserVars.moons.select { |moon_name, moon_data| UserVars.moons['visible'].include?(moon_name) && moon_data['timer'] >= 4 }
            .map { |moon_name, _moon_data| moon_name }
  end

  def check_moonwatch
    return if Script.running?('moonwatch')

    echo 'moonwatch is not running. Starting it now'
    UserVars.moons = {}
    custom_require.call('moonwatch')
    echo "Run `#{$clean_lich_char}e autostart('moonwatch')` to avoid this in the future"
    pause 0.5 while UserVars.moons.empty?
  end
end
