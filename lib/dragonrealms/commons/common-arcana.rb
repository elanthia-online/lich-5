module Lich
module DragonRealms
module DRCA
  module_function

  @@cyclic_release_success_patterns = [
    # Ranger spells
    /^The world seems to accelerate around you as the spirit of the cheetah escapes you/, # Cheetah Swiftness
    /^You feel distinctly frail and vulnerable as the spirit of the bear leaves you/, # Bear Strength
    /^The forces of nature that you roused are no longer with you/, # Awaken Forest
    # Empath spells
    /^Aesandry Darlaeth loses cohesion, returning your reaction time to normal/, # Aesandry Darlaeth
    /^You sense your hold on your Guardian Spirit weaken, then evaporate entirely/, # Guardian Spirit
    /^The signs of empathic atrocity escape to the deepest pits of your personality, your touch no longer deadly/, # Icutu Zaharenela
    /^The tingling across your body diminishes as you feel the motes of energy fade away/, # Regenerate
    # Bard spells
    /^You sing, purposely warbling some of the held notes for effec/, # Abandoned Heart (ABAN)
    /^The final tones of your enchante end with an abrupt flourish that leaves stark silence in its wake/, # Aether Wolves (AEWO)
    /^With a rising crescendo in your voice, you reprise the strong lines of the chorus of Albreda's Balm before bringing it to an abrupt conclusion/, # Albreda's Balm (ALB)
    /^The final, quiet notes of Blessing of the Fae stir the air gently, and die away/, # Blessing of the Fae (BOTF)
    /^The warm air swirling around you stills and begins to cool/, # Caress of the Sun (CARE)
    /^A few fleeting, soporific notes tarry in the air before your lullaby slowly dies down like the night receding at Anduwen/, # Damaris' Lullaby (DALU)
    /^You no longer feel the clarity of vision you had, as shadows creep across the area/, # Eye of Kertigen (EYE)
    /^You let your voice fade even as the pace of Faenella's Grace slows, winding down to a quiet conclusion/, # Faenella's Grace (FAE)
    /^The aethereal static subsides, returning your spellcasting abilities to normal/, # Glythtide's Joy (GJ)
    /^As your rendition of Hodierna's Lilt winds down to a close, you let each note linger on the air a moment, drawing out the final moment with a reluctance to let the soothing melody fade/, # Hodierna's Lilt (HODI)
    /^You build the final notes of Phoenix's Pyre with an upward scale that rises into a steep crescendo, and end with an abrupt silence/, # Phoenix's Pyre (PYRE)
    /^The dome of light extinguishes as the final notes of music die away/, # Sanctuary
    # Warrior Mage spels
    /^The dark mantle of aether surrounding you fades away/, # Aether Cloak (AC)
    /^You release your connection to the Elemental Plane of Electricity, allowing the static electricity to dissipate/, # Electrostatic Eddy (EE)
    /^Your link to the Fire Rain matrix has been severed/, # Fire Rain (FR)
    /^The chilling vapor surrounding you dissipates slowly/, # Rimefang (spell) (RIM)
    /^The frost-covered blade circling around you shatters into a fine icy mist/, # Rimefang (spell) (RIM)
    /^The jagged stone spears surrounding you at .* range tremble slightly, then crumble into a grey dust that is quickly reclaimed by the earth/, # Ring of Spears (ROS)
    # Cleric spells
    /^The deadening murk around you subsides/, # Hydra Hex (HYH)
    /^The dark patch of grime around you subsides/, # Hydra Hex (HYH)
    /^You sense the dark presence depart/, # Soul Attrition (SA)
    # Resurrection (REZZ) does not have messaging that makes it usable here.
    /^The heightened sense of spiritual awareness leaves you/, # Revelation (REV)
    /^The swirling fog dissipates from around you/, # Ghost Shroud (GHS)
    # Paladin spells
    /^The holy golden radiance of your soul subsides, retreating into your body/, # Holy Warrior (HOW)
    /^Truffenyi's Rally ends, leaving behind a momentary sensation of something stuck in your throat/, # Truffenyi's Rally (TR)
    # Moon Mage spells
    /^The web of shadows twitches one last time and then goes inert/, # Shadow Web (SHW)
    /^You release your mental hold on the lunar energy that sustains your moongate/, # Moongate (MG)
    /^The refractive field surrounding you fades away/, # Steps of Vuan (SOV)
    /^A \w+ brilliant \w+ sphere suddenly flares with a cold light and vaporizes/, # Starlight Sphere (SLS)
    # Trader spells
    /^Your calligraphy of light assailing/, # Arbiter's Stylus (ARS)
    /^The .* moonsmoke blows away from your face/, # Mask of the Moons (MOM)
    # Necromancer spells
    /^The Rite of Contrition matrix loses cohesion, leaving your aura naked/, # Rite of Contrition (ROC)
    /^The Rite of Forbearance matrix loses cohesion, leaving you to wallow in temptation/, # Rite of Forbearance (ROF)
    /^The Rite of Grace matrix loses cohesion, leaving your body exposed/, # Rite of Grace (ROG)
    /^The greenish hues about you vanish as the Universal Solvent matrix loses its cohesion/, # Universal Solvent (USOL)
    /^You sense your Call from Within spell weaken and disperse/ # Call from Within (CFW)
  ]

  def infuse_om(harness, amount)
    return unless DRSpells.active_spells['Osrel Meraud'] && DRSpells.active_spells['Osrel Meraud'] < 90
    return unless amount

    success = ['having reached its full capacity', 'A sense of fullness', 'Something in the area is interfering with your attempt to harness']
    failure = ['as if it hungers for more', 'Your infusion fails completely', 'You don\'t have enough harnessed mana to infuse that much', 'You have no harnessed']

    loop do
      pause 5 while DRStats.mana <= 40
      harness_mana([amount]) if harness
      break if success.include?(DRC.bput("infuse om #{amount}", success, failure))

      pause 0.5
      waitrt?
    end
  end

  def harness?(mana)
    result = DRC.bput("harness #{mana}", 'You tap into', 'Strain though you may')
    pause 0.5
    waitrt?
    return result =~ /You tap into/
  end

  def harness_mana(amounts)
    amounts.each do |mana|
      break unless harness?(mana)
    end
  end

  def start_khris(khris, settings)
    khris
      .each do |khri_set|
        activate_khri?(settings.kneel_khri, khri_set)
      end
  end

  # Needs to handle (based on current usage):
  # - Hasten
  # - Delay Hasten
  # - Hasten Focus
  # - Delay Hasten Focus
  # - Khri Hasten
  # - Khri Delay Hasten
  # - Khri Delay Hasten Focus
  def activate_khri?(settings_kneel, ability)
    abilities = ability.split.map(&:capitalize)

    # Standardize for with/without 'Khri' on the front
    abilities = abilities.drop(1) if abilities.first.casecmp('khri') == 0

    # Handling for 'Delay'
    should_delay = abilities.first.casecmp('delay') == 0
    abilities = abilities.drop(1) if should_delay

    # Check each khri in the list against Active Spells, Drop any that are active
    needed_abilities = abilities.select { |ability_to_check| DRSpells.active_spells["Khri #{ability_to_check}"].nil? }
    return true if needed_abilities.empty?

    kneel = needed_abilities.any? { |ability_to_check| kneel_for_khri?(settings_kneel, ability_to_check) }
    DRC.retreat if kneel
    DRC.bput('kneel', 'You kneel', 'You are already', 'You rise', "While swimming?  Don't be silly") if kneel && !kneeling?

    result = DRC.bput("Khri #{should_delay ? 'Delay ' : ''}#{needed_abilities.join(' ')}", get_data('spells').khri_preps)
    waitrt?
    DRC.fix_standing

    return ['Your mind and body are willing', 'Your body is willing', 'You have not recovered'].none?(result)
  end

  def kneel_for_khri?(kneel, ability)
    if kneel.is_a? Array
      kneel.map(&:downcase).include? ability.downcase.sub('khri ', '')
    else
      kneel
    end
  end

  def start_barb_abilities(abilities, settings)
    abilities.each { |name| activate_barb_buff?(name, settings.meditation_pause_timer, settings.sit_to_meditate) }
  end

  def activate_barb_buff?(name, meditation_pause_timer = 20, sit_to_meditate = false)
    # Note, you must know Power meditation or Powermonger mastery
    # for your active abilities to be detected by DRSpells.
    return true if DRSpells.active_spells[name]

    activated = false
    ability_data = get_data('spells').barb_abilities[name]
    if ability_data['type'].eql?('meditation') && sit_to_meditate
      DRC.retreat
      DRC.bput('sit', 'You sit', 'You are already', 'You rise', 'While swimming?')
    end
    case DRC.bput(ability_data['start_command'], ability_data['activated_message'], 'You have not been trained', 'But you are already', 'Your inner fire lacks', 'find yourself lacking the inner fire', 'You should stand', 'You must be sitting', 'You must be unengaged', 'While swimming?')
    when 'You must be unengaged'
      DRC.retreat
      activated = activate_barb_buff?(name, meditation_pause_timer)
    when 'You must be sitting'
      DRC.retreat
      case DRC.bput('sit', 'You sit', 'You are already', 'You rise', 'While swimming?')
      when 'While swimming?'
        activated = false # can't sit here, water is too deep
      else
        activated = activate_barb_buff?(name, meditation_pause_timer)
      end
    when 'You should stand'
      DRC.fix_standing
      activated = activate_barb_buff?(name, meditation_pause_timer)
    when /#{ability_data['activated_message']}/
      # Pause at least for the preferred amount of time
      # to let the meditation take effect else it may fail.
      if ability_data['type'].eql?('meditation') && meditation_pause_timer
        pause meditation_pause_timer
      end
      # Wait for any remaining RT before proceeding
      waitrt?
      activated = true
    else
      activated = false
    end
    DRC.fix_standing
    activated
  end

  def prepare?(abbrev, mana, symbiosis = false, command = 'prepare', tattoo_tm = false, runestone_name = nil, runestone_tm = false)
    return false unless abbrev

    DRC.bput('prepare symbiosis', 'You recall the exact details of the', 'But you\'ve already prepared', 'Please don\'t do that here') if symbiosis

    if runestone_name.nil?
      match = DRC.bput("#{command} #{abbrev} #{mana}", get_data('spells').prep_messages)
    else
      match = DRC.bput("#{command} my #{runestone_name}", get_data('spells').invoke_messages)
    end
    case match
    when 'Your desire to prepare this offensive spell suddenly slips away'
      pause 1
      return prepare?(abbrev, mana, symbiosis, command, tattoo_tm, runestone_name, runestone_tm)
    when 'Something in the area interferes with your spell preparations', 'You shouldn\'t disrupt the area right now', 'You have no idea how to cast that spell', 'You have yet to receive any training in the magical arts', 'Please don\'t do that here', 'You cannot use the tattoo while maintaining the effort to stay hidden'
      DRC.bput('release symbiosis', 'You release the', 'But you haven\'t') if symbiosis
      return false
    when 'Well, that was fun'
      DRCI.dispose_trash(runestone_name)
      return false
    when 'You\'ll have to hold it'
      return false
    end

    DRC.bput("target", get_data('spells').prep_messages) if tattoo_tm || runestone_tm

    match
  end

  # Returns true if preparing a spell, false otherwise.
  def spell_preparing?
    !spell_preparing.nil?
  end

  # Returns true if you're prepared to cast your spell.
  # Infers this if you're preparing a spell and there's no more prep time to wait.
  def spell_prepared?
    spell_preparing? && checkcastrt <= 0
  end

  # Returns name of the spell being prepared, or nil if not preparing one.
  def spell_preparing
    name = XMLData.prepared_spell
    name = nil if name.empty? || name.eql?('None')
    name
  end

  def ritual(data, settings)
    DRC.retreat(settings.ignored_npcs) unless data['skip_retreat']
    DRC.release_invisibility
    DRC.set_stance('shield') unless data['skip_retreat']

    command = 'prepare'
    command = data['prep'] if data['prep']
    command = data['prep_type'] if data['prep_type']

    return unless prepare?(data['abbrev'], data['mana'], data['symbiosis'], command, data['tattoo_tm'], data['runestone_name'], data['runestone_tm'])

    prepare_time = Time.now
    find_focus(data['focus'], data['worn_focus'], data['tied_focus'], data['sheathed_focus'])

    invoke(data['focus'], nil, nil)
    stow_focus(data['focus'], data['worn_focus'], data['tied_focus'], data['sheathed_focus'])
    DRC.retreat(settings.ignored_npcs) unless data['skip_retreat']

    if data['prep_time']
      pause until Time.now - prepare_time >= data['prep_time']
    else
      waitcastrt?
    end

    return unless cast?(data['cast'], data['symbiosis'], data['before'], data['after'])

    DRC.retreat(settings.ignored_npcs) unless data['skip_retreat']
  end

  def prepare_to_cast_runestone?(spell, settings)
    if DRCI.inside?("#{spell['runestone_name']}", settings.runestone_storage)
      return false if !get_runestone?(spell['runestone_name'], settings)
    else
      DRC.message("*** Out of #{spell['runestone_name']}! ***")
      return false
    end
    return true
  end

  def get_runestone?(runestone, settings)
    return true if DRCI.in_hands?(runestone)

    DRCI.get_item(runestone, settings.runestone_storage)
    if reget(3, "You get a useless #{runestone}")
      DRCI.dispose_trash(runestone)
      return false
    end
    return true
  end

  def cast?(cast_command = 'cast', symbiosis = false, before = [], after = [])
    before.each { |action| DRC.bput(action['message'], action['matches']) }

    Flags.add('unknown-command', "Please rephrase that command")
    Flags.add('barrage-fail', "That was an invalid attack choice.", "Wouldn't it be better if you used a melee weapon?", "You'll need to be using a weapon to BARRAGE your target", "You must have a fully developed target matrix to make a barrage attack", "You are unable to muster the energy to do that", "You do not know how to manipulate that pathway.", "You cannot BARRAGE with that spell.")
    Flags.add('spell-fail', 'Currently lacking the skill to complete the pattern', 'backfires', 'Something is interfering with the spell', 'There is nothing else to face', 'You strain, but are too mentally fatigued')
    Flags.add('cyclic-too-recent', 'The mental strain of initiating a cyclic spell so recently prevents you from formulating the spell pattern')
    Flags.add('spell-full-prep', /^This pattern may only be cast with full preparation/)

    case DRC.bput(cast_command || 'cast', get_data('spells').cast_messages)
    when /^Your target pattern dissipates/, /^You can't cast that at yourself/, /^You need to specify a body part to consume/, /^There is nothing else to face/
      DRC.bput('release spell', 'You let your concentration lapse', "You aren't preparing a spell")
      DRC.bput('release mana', 'You release all', "You aren't harnessing any mana")
    when /You gesture/
      pause 0.25
    end
    waitrt?

    # Warrior Mage failed to use (or doesn't know) barrage ability. Do regular cast instead.
    if cast_command =~ /\b(barrage)\b/i && (Flags['unknown-command'] || Flags['barrage-fail'])
      cast?('cast', symbiosis, [], after)
    end

    if Flags['cyclic-too-recent'] || Flags['spell-full-prep']
      pause 1
      Flags.delete('spell-full-prep')
      return cast?(cast_command, symbiosis, [], after)
    end

    after.each { |action| DRC.bput(action['message'], action['matches']) }

    if symbiosis && Flags['spell-fail']
      DRC.bput('release mana', 'You release all', "You aren't harnessing any mana")
      DRC.bput('release symbiosis', 'You release', 'But you haven\'t prepared')
    elsif Flags['spell-fail']
      DRC.bput('release mana', 'You release all', "You aren't harnessing any mana")
    end

    !Flags['spell-fail']
  end

  def find_charge_invoke_stow(cambrinth, stored_cambrinth, cambrinth_cap, dedicated_camb_use, charges, invoke_exact_amount = nil)
    # TODO: Remove default nil argument once all users are up to date with common-arcana
    return unless charges

    find_cambrinth(cambrinth, stored_cambrinth, cambrinth_cap)
    charge_and_invoke(cambrinth, dedicated_camb_use, charges, invoke_exact_amount)
    stow_cambrinth(cambrinth, stored_cambrinth, cambrinth_cap)
  end

  def find_focus(focus, worn, tied, sheathed)
    return unless focus

    if worn
      DRC.bput("remove my #{focus}", 'You remove', 'You slide', 'You sling', 'You take')
    elsif tied
      DRC.bput("untie my #{focus} from my #{tied}", 'You remove', '[Y|y]ou untie')
    elsif sheathed
      DRC.bput("wield my #{focus}", 'You draw out your')
    else
      DRC.bput("get my #{focus}", 'You get')
    end
  end

  def stow_focus(focus, worn, tied, sheathed)
    return unless focus

    if worn
      DRC.bput("wear my #{focus}", 'You attach', 'You slide', 'You are already wearing', 'You hang', 'You sling', 'You put', 'You place')
    elsif tied
      case DRC.bput("tie my #{focus} to my #{tied}", 'You attach', '[Y|y]ou tie', 'You are a little too busy to be worrying')
      when 'You are a little too busy to be worrying'
        DRC.retreat
        stow_focus(focus, worn, tied, sheathed)
      end
    elsif sheathed
      DRC.bput("sheathe #{focus}", "You sheathe")
    else
      DRC.bput("stow my #{focus}", 'You put', 'You easily strap your')
    end
  end

  def find_cambrinth(cambrinth, stored_cambrinth, cambrinth_cap)
    if stored_cambrinth
      # Your config says you keep your cambrinth stowed.
      # If item not in your hands, maybe you're wearing it by accident?
      DRCI.get_item_if_not_held?(cambrinth) || DRCI.remove_item?(cambrinth)
    elsif !skilled_to_charge_while_worn?(cambrinth_cap)
      # Your config says you wear your cambrinth.
      # But you're not skilled to charge it while worn.
      # If item not in your hands, maybe you're wearing it or stowed it by accident?
      DRCI.in_hands?(cambrinth) || DRCI.remove_item?(cambrinth) || DRCI.get_item?(cambrinth)
    else
      # Your config says you wear your cambrinth
      # and you're skilled to charge it while worn.
      # Let's hope you're wearing or holding it :)
      # To verify that would require more commands
      # and more time, and be more spammy.
      # For now, no validation or recovery for this scenario.
      true
    end
  end

  def stow_cambrinth(cambrinth, stored_cambrinth, _cambrinth_cap)
    if stored_cambrinth
      # Your config says you keep your cambrinth stowed.
      # If item not in your hands and not stowed, maybe you're wearing it by accident?
      DRCI.get_item_if_not_held?(cambrinth) || DRCI.remove_item?(cambrinth)
      DRCI.stow_item?(cambrinth)
    elsif DRCI.in_hands?(cambrinth)
      # Your config says you wear your cambrinth.
      # For some reason it's currently in your hands.
      # If can't wear item for some reason then stow it.
      DRCI.wear_item?(cambrinth) || DRCI.stow_item?(cambrinth)
    else
      # Your config says you wear your cambrinth
      # and you're not currently holding it so
      # we'll assume you're wearing it.
      # No further action needed.
      true
    end
  end

  def skilled_to_charge_while_worn?(cambrinth_cap)
    DRSkill.getrank('Arcana').to_i >= ((cambrinth_cap.to_i * 2) + 100)
  end

  def charge_and_invoke(cambrinth, dedicated_camb_use, charges, invoke_exact_amount = nil)
    # TODO: Remove default nil argument once all users are up to date with common-arcana
    charges.each do |mana|
      break unless charge?(cambrinth, mana)
    end

    invoke_amount = invoke_exact_amount ? charges.inject(:+) : nil

    invoke(cambrinth, dedicated_camb_use, invoke_amount)
  end

  def invoke(cambrinth, dedicated_camb_use, invoke_amount)
    return unless cambrinth

    result = DRC.bput("invoke my #{cambrinth} #{invoke_amount} #{dedicated_camb_use}".strip, get_data('spells').invoke_messages, 'Invoke what?')
    pause
    waitrt?
    case result
    when /you find it too clumsy/
      DRC.message("*** Your arcana skill is too low to invoke your cambrinth while worn")
      # If the cambrinth is in your hands and you can't invoke it, nothing else to do.
      unless DRCI.in_hands?(cambrinth)
        # Otherwise, try to find the cambrinth and get it to your hands.
        find_cambrinth(cambrinth, false, 999)
        # If you were able to get the cambrinth into a hand then retry invoking it.
        # You might not have been able to if your hands were full.
        if DRCI.in_hands?(cambrinth)
          invoke(cambrinth, dedicated_camb_use, invoke_amount)
          stow_cambrinth(cambrinth, false, 999)
        end
      end
    end
  end

  def charge?(cambrinth, mana)
    charged = false
    result = DRC.bput("charge my #{cambrinth} #{mana}", get_data('spells').charge_messages, 'I could not find')
    pause
    waitrt?
    case result
    when /You are in no condition to do that/
      charged = harness?(mana)
    when /You'll have to hold it/
      # Your not wearing nor holding your cambrinth item, go find it again.
      # Likely it's configured in your yaml that you wear it but it's stowed for some reason.
      # Try to find the cambrinth and get it to your hands.
      DRC.message("*** Where did your cambrinth go?")
      retry_find_cambrinth = true
    when /you find it too clumsy/
      DRC.message("*** Your arcana skill is too low to charge your cambrinth while worn")
      retry_find_cambrinth = true
    else
      charged = result =~ /absorbs? all of the energy/
    end
    if retry_find_cambrinth
      # If the cambrinth is in your hands and you can't charge it, nothing else to do.
      unless DRCI.in_hands?(cambrinth)
        # Otherwise, try to find the cambrinth and get it to your hands.
        find_cambrinth(cambrinth, false, 999)
        # If you were able to get the cambrinth into a hand then retry charging it.
        # You might not have been able to if your hands were full.
        if DRCI.in_hands?(cambrinth)
          charged = charge?(cambrinth, mana)
          stow_cambrinth(cambrinth, false, 999)
        end
      end
    end
    return charged
  end

  def release_cyclics(cyclic_no_release = [])
    get_data('spells')
      .spell_data
      .select { |_name, properties| properties['cyclic'] }
      .select { |name, _properties| DRSpells.active_spells.keys.include?(name) }
      .reject { |name| cyclic_no_release.include?(name) }
      .map { |_name, properties| properties['abbrev'] }
      .each { |abbrev| DRC.bput("release #{abbrev}", @@cyclic_release_success_patterns, 'Release what?') }
  end

  def parse_regalia # generates an array of currently-worn regalia armor nouns
    return unless DRStats.trader?

    DRC.bput('inv armor', 'Use INVENTORY HELP for more options')
    snapshot = reget(40)
    if snapshot.grep(/All of your armor|You aren't wearing anything like that/).any? && snapshot.grep(/Use INVENTORY HELP/).any?
      snapshot
        .map(&:strip)
        .reverse
        .take_while { |item| !['All of your armor:', "You aren't wearing anything like that."].include?(item) }
        .drop_while { |item| item != '[Use INVENTORY HELP for more options.]' }
        .drop(1)
        .select { |item| item.include?('rough-cut crystal') || item.include?('faceted crystal') || item.include?('resplendent crystal') }
        .map { |item| DRC.get_noun(item) }
    else
      parse_regalia
    end
  end

  def shatter_regalia?(worn_regalia = nil) # takes an array of armor nouns to remove or gets its own from parse_regalia
    return false unless DRStats.trader?

    worn_regalia ||= parse_regalia
    return false if worn_regalia.empty?

    worn_regalia.each do |item|
      DRC.bput("remove my #{item}", 'into motes of silvery', 'Remove what?', "You .*#{item}")
    end
    true
  end

  def parse_mana_message(mana_msg)
    manalevels = if mana_msg.include? 'weak'
                   $MANA_MAP['weak']
                 elsif mana_msg.include? 'developing'
                   $MANA_MAP['developing']
                 elsif mana_msg.include? 'improving'
                   $MANA_MAP['improving']
                 else
                   $MANA_MAP['good']
                 end

    adj = mana_msg.split(' ')[-1]

    manalevels.index(adj).to_i + 1
  end

  def perc_mana
    return nil if DRStats.barbarian? || DRStats.thief? || DRStats.trader? || DRStats.commoner?

    if DRStats.moon_mage?
      DRC.bput('perc mana', 'the Psychic Projection book.')
      mana_msgs = reget(5)[0..3]

      mana_msgs.collect! do |mana_msg|
        mana_msg.split(' streams')[0]
      end

      mana_levels = {}
      mana_levels['enlightened_geometry'] = parse_mana_message(mana_msgs[0])
      mana_levels['moonlight_manipulation'] = parse_mana_message(mana_msgs[1])
      mana_levels['perception'] = parse_mana_message(mana_msgs[2])
      mana_levels['psychic_projection'] = parse_mana_message(mana_msgs[3])
      return mana_levels
    else
      mana_msg = DRC.bput('perc', '^You reach out with your .* and (see|hear) \w+')
      return parse_mana_message(mana_msg)
    end
  end

  def perc_aura
    return unless DRStats.trader?

    starlight_messages = [
      'The smallest hint of starlight flickers within your aura',
      'A bare flicker of starlight plays within your aura',
      'A faint amount of starlight illuminates your aura',
      'Your aura pulses slowly with starlight',
      'A steady pulse of starlight runs through your aura',
      'Starlight dances vividly across the confines of your aura',
      'Strong pulses of starlight flare within your aura',
      'Your aura seethes with brilliant starlight',
      'Your aura is blinding',
      'The power contained in your aura'
    ]
    Flags.add('aura-level', Regexp.union(starlight_messages))
    Flags.add('aura-capped?', 'Your aura contains as much starlight as you can safely handle')
    Flags.add('aura-growing?', 'Local conditions permit optimal growth of your aura', 'Local conditions are hindering the growth of your aura')
    aura = {}
    DRC.bput('perceive aura', 'Roundtime')
    aura['level'] = Flags['aura-level'] ? starlight_messages.index(Flags['aura-level'][0]) : 0
    aura['capped'] = Flags['aura-capped?'] ? true : false
    aura['growing'] = Flags['aura-growing?'] ? true : false
    Flags.delete('aura-level')
    Flags.delete('aura-capped?')
    Flags.delete('aura-growing?')
    aura
  end

  def cast_spells(spells, settings, force_cambrinth = false, cast_lifecycle_lambda = nil)
    infuse_om(!settings.osrel_no_harness, settings.osrel_amount)
    spells.each do |name, data|
      next if DRSpells.active_spells[name] && (data['recast'].nil? || DRSpells.active_spells[name].to_i > data['recast'])

      while (DRStats.mana < settings.waggle_spells_mana_threshold || DRStats.concentration < settings.waggle_spells_concentration_threshold)
        echo("Waiting on mana over #{settings.waggle_spells_mana_threshold} or concentration over #{settings.waggle_spells_concentration_threshold}...")
        pause 15
      end
      cast_spell(data, settings, force_cambrinth, cast_lifecycle_lambda)
    end
  end

  def cast_spell?(data, settings, force_cambrinth = false, cast_lifecycle_lambda = nil)
    result = cast_spell(data, settings, force_cambrinth, cast_lifecycle_lambda)
    result ? true : false
  end

  def cast_spell(data, settings, force_cambrinth = false, cast_lifecycle_lambda = nil)
    return unless data
    return unless settings

    data = DRCMM.update_astral_data(data, settings)
    return unless data # DRCMM.update_astral_data returns nil on failure

    if (data['abbrev'] =~ /locat/i) && !DRSpells.active_spells['Clear Vision']
      cast_spell({ 'abbrev' => 'cv', 'mana' => 1, 'prep_time' => 5 }, settings)
    end

    if data['ritual']
      ritual(data, settings)
      return
    end

    if data['runestone_name']
      if !prepare_to_cast_runestone?(data, settings)
        return
      end
    end

    cast_lifecycle_lambda.call('pre-prep', data, settings) if cast_lifecycle_lambda != nil

    command = 'prep'
    command = data['prep'] if data['prep']
    command = data['prep_type'] if data['prep_type']

    if command == 'segue'
      return if segue?(data['abbrev'], data['mana'])

      command = 'prep'
    end

    release_cyclics if data['cyclic']
    DRC.bput('release spell', 'You let your concentration lapse', "You aren't preparing a spell") unless checkprep == 'None'
    DRC.bput('release mana', 'You release all', "You aren't harnessing any mana")

    return unless prepare?(data['abbrev'], data['mana'], data['symbiosis'], command, data['tattoo_tm'], data['runestone_name'], data['runestone_tm'])

    DRCI.put_away_item?(data['runestone_name'], settings.runestone_storage) if DRCI.in_hands?(data['runestone_name'])
    prepare_time = Time.now

    unless settings.cambrinth_items[0]['name']
      settings.cambrinth_items = [{
        'name'   => settings.cambrinth,
        'cap'    => settings.cambrinth_cap,
        'stored' => settings.stored_cambrinth
      }]
    end
    if check_to_harness(settings.use_harness_when_arcana_locked) && !force_cambrinth
      harness_mana(data['cambrinth'].flatten)
    else
      settings.cambrinth_items.each_with_index do |item, index|
        case data['cambrinth'].first
        when Array
          find_charge_invoke_stow(item['name'], item['stored'], item['cap'], settings.dedicated_camb_use, data['cambrinth'][index], settings.cambrinth_invoke_exact_amount)
        when Integer
          find_charge_invoke_stow(item['name'], item['stored'], item['cap'], settings.dedicated_camb_use, data['cambrinth'], settings.cambrinth_invoke_exact_amount)
        end
      end
    end

    cast_lifecycle_lambda.call('post-prep', data, settings) if cast_lifecycle_lambda != nil

    if data['prep_time']
      pause until Time.now - prepare_time >= data['prep_time']
    else
      waitcastrt?
    end

    cast_lifecycle_lambda.call('pre-cast', data, settings) if cast_lifecycle_lambda != nil
    spell_cast = cast?(data['cast'], data['symbiosis'], data['before'], data['after'])
    cast_lifecycle_lambda.call('post-cast', data, settings) if cast_lifecycle_lambda != nil

    return spell_cast
  end

  def segue?(abbrev, mana)
    case DRC.bput("segue #{abbrev} #{mana}", get_data('spells').segue_messages)
    when 'You must be performing a cyclic spell to segue from', 'It is too soon to segue', 'You are lacking the bardic flair'
      return false
    end
    true
  end

  def check_discern(data, settings, spell_is_sorcery = false, more_override = nil)
    UserVars.discerns = {} unless UserVars.discerns
    discern_data = UserVars.discerns[data['abbrev']] || {}
    if data['symbiosis'] || spell_is_sorcery
      if discern_data.empty? || discern_data['min'].nil? || more_override
        DRC.retreat
        /requires at minimum (\d+) mana streams/ =~ DRC.bput("discern #{data['abbrev']}", 'requires at minimum \d+ mana streams')
        discern_data['mana'] = Regexp.last_match(1).to_i
        discern_data['cambrinth'] = nil
        discern_data['min'] = Regexp.last_match(1).to_i
        discern_data['more'] = (more_override ? more_override : 0)
      end
      calculate_mana(discern_data['min'], discern_data['more'], discern_data, false, settings)
    elsif discern_data.empty? || discern_data['time_stamp'].nil? || Time.now - discern_data['time_stamp'] > settings.check_discern_timer_in_hours * 60 * 60 || !discern_data['more'].nil?
      discern_data['time_stamp'] = Time.now
      DRC.retreat
      case discern = DRC.bput("discern #{data['abbrev']}", 'The spell requires at minimum \d+ mana streams and you think you can reinforce it with \d+ more', 'You don\'t think you are able to cast this spell', 'You have no idea how to cast that spell', 'You don\'t seem to be able to move to do that')
      when /you don't think you are able/i, 'You have no idea how to cast that spell', 'You don\'t seem to be able to move to do that'
        discern_data['mana'] = 1
        discern_data['cambrinth'] = nil
      else
        discern =~ /minimum (\d+) mana streams and you think you can reinforce it with (\d+) more/i
        calculate_mana(Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, discern_data, data['cyclic'] || data['ritual'], settings)
      end
    end
    pause 1
    waitrt?
    UserVars.discerns[data['abbrev']] = discern_data
    data['mana'] = discern_data['mana']
    data['cambrinth'] = discern_data['cambrinth']
    data
  end

  def calculate_mana(min, more, discern_data, cyclic_or_ritual, settings)
    total = min + more
    total = (total * settings.prep_scaling_factor).floor
    discern_data['mana'] = [(total / 5.0).ceil, min].max
    remaining = total - discern_data['mana']
    unless settings.cambrinth_items[0]['name']
      settings.cambrinth_items = [{
        'name'   => settings.cambrinth,
        'cap'    => settings.cambrinth_cap,
        'stored' => settings.stored_cambrinth
      }]
    end
    # Ignore cambrinth if charges to use is nil or 0
    settings.cambrinth_num_charges ||= 0
    settings.cambrinth_items = [] if settings.cambrinth_num_charges == 0
    total_cambrinth_cap = settings.cambrinth_items.map { |x| x['cap'] }.inject(&:+) || 0
    charges_count_floor = remaining >= settings.cambrinth_num_charges ? settings.cambrinth_num_charges : 1
    settings.cambrinth_items.each do |item|
      item['charges'] = ((item['cap'].to_f / total_cambrinth_cap) * charges_count_floor).ceil
    end
    total_cambrinth_charges = settings.cambrinth_items.map { |x| x['charges'] }.inject(&:+) || 0
    if remaining > total_cambrinth_cap
      discern_data['mana'] = discern_data['mana'] + (remaining - total_cambrinth_cap)
      remaining = total - discern_data['mana']
    end
    if cyclic_or_ritual || total_cambrinth_charges == 0
      discern_data['cambrinth'] = nil
      discern_data['mana'] = discern_data['mana'] + remaining
    elsif remaining > 0
      total_cambrinth_mana = [remaining, total_cambrinth_cap].min
      settings.cambrinth_items.each_with_index do |item, index|
        discern_data['cambrinth'] ||= []
        charge_amount = (total_cambrinth_mana / total_cambrinth_charges) * item['charges']
        discern_data['cambrinth'][index] = []
        charge_amount.times do |i|
          discern_data['cambrinth'][index][i % item['charges']] += 1
        end
      end
    else
      discern_data['cambrinth'] = nil
    end
  end

  def check_to_harness(should_harness)
    return false unless should_harness
    return false if DRSkill.getxp('Attunement') > DRSkill.getxp('Arcana')

    true
  end

  def crafting_cast_spell(data, settings)
    return unless data
    return unless settings

    unless settings.cambrinth_items[0]['name']
      settings.cambrinth_items = [{
        'name'   => settings.cambrinth,
        'cap'    => settings.cambrinth_cap,
        'stored' => settings.stored_cambrinth
      }]
    end
    if check_to_harness(settings.use_harness_when_arcana_locked)
      harness_mana(data['cambrinth'].flatten)
    else
      settings.cambrinth_items.each_with_index do |item, index|
        case data['cambrinth'].first
        when Array
          find_charge_invoke_stow(item['name'], item['stored'], item['cap'], settings.dedicated_camb_use, data['cambrinth'][index], settings.cambrinth_invoke_exact_amount)
        when Integer
          find_charge_invoke_stow(item['name'], item['stored'], item['cap'], settings.dedicated_camb_use, data['cambrinth'], settings.cambrinth_invoke_exact_amount)
        end
      end
    end

    cast?(data['cast'], data['symbiosis'], data['before'], data['after'])
  end

  def crafting_prepare_spell(data, settings)
    return unless data
    return unless settings

    # Skip preparing lunar spell if no moons available
    return unless DRCMM.set_moon_data(data)

    release_cyclics if data['cyclic']
    DRC.bput('release spell', 'You let your concentration lapse', "You aren't preparing a spell") unless checkprep == 'None'
    DRC.bput('release mana', 'You release all', "You aren't harnessing any mana")

    command = 'prep'
    command = data['prep'] if data['prep']
    command = data['prep_type'] if data['prep_type']

    prepare?(data['abbrev'], data['mana'], data['symbiosis'], command, data['tattoo_tm'], data['runestone_name'], data['runestone_tm'])
  end

  def crafting_magic_routine(settings)
    training_spells = settings.crafting_training_spells

    return if training_spells.empty?
    return if DRStats.mana <= settings.waggle_spells_mana_threshold

    if !XMLData.prepared_spell.eql?('None') && checkcastrt == 0
      spell = XMLData.prepared_spell
      data = training_spells.find { |_skill, info| info['name'] == spell }.last
      crafting_cast_spell(data, settings)
    end

    return if checkcastrt > 0

    needs_training = %w[Warding Utility Augmentation]
    needs_training.append("Sorcery") if (settings.crafting_training_spells_enable_sorcery && !Script.running?('forge')) ||
                                        (settings.crafting_training_spells_enable_sorcery && settings.crafting_training_spells_enable_sorcery_forging)
    needs_training = needs_training.select { |skill| training_spells[skill] }
                                   .select { |skill| DRSkill.getxp(skill) < 31 }
                                   .sort_by { |skill| [DRSkill.getxp(skill), DRSkill.getrank(skill)] }
                                   .first

    return unless needs_training

    crafting_prepare_spell(training_spells[needs_training], settings)
  end

  def do_buffs(settings, set_name)
    # takes a waggle and sends it to the appropriate helper
    return unless settings.waggle_sets[set_name]

    spells = settings.waggle_sets[set_name]

    if DRStats.barbarian?
      start_barb_abilities(spells, settings)
    elsif DRStats.thief?
      start_khris(spells, settings)
    else
      spells
        .select! { |_name, data| data['night'] ? UserVars.sun['night'] : true }
        .select! { |_name, data| data['day'] ? UserVars.sun['day'] : true }

      spells.values
            .select { |spell| spell['use_auto_mana'] }
            .each { |spell| check_discern(spell, settings) }

      cast_spells(spells, settings, settings.waggle_force_cambrinth)
    end
  end

  def update_avtalia
    DRC.bput("focus cambrinth", /^The .+ pulses? .+ (\d+)/, 'dim, almost magically null', '^You let your magical senses wander')
    waitrt?
  end

  def invoke_avtalia(cambrinth, dedicated_camb_use, invoke_amount)
    return unless cambrinth
    return unless Script.running?('avtalia')

    invoke(cambrinth, dedicated_camb_use, invoke_amount)
    UserVars.avtalia[cambrinth]['mana'] -= [DRStats.mana, invoke_amount].min
  end

  def charge_avtalia(cambrinth, charge_amount)
    return unless cambrinth
    return unless Script.running?('avtalia')

    if !charge?(cambrinth, charge_amount)
      UserVars.avtalia[cambrinth]['mana'] = UserVars.avtalia[cambrinth]['cap']
    else
      # Experiments show very roughly 10% falloff regardless of cap every 10 minutes
      # Assume 10% every 5 minutes.  No falloff in starlight, but that's not tracked ATM.
      time_diff = Time.now - UserVars.avtalia[cambrinth]['time_seen']
      time_mod = (time_diff / 300.0).floor
      time_adjust = 1 - [time_mod * 0.10, 1.0].min
      assumed_reserve = (UserVars.avtalia[cambrinth]['mana'] * time_adjust).floor + charge_amount
      UserVars.avtalia[cambrinth]['mana'] = [assumed_reserve, UserVars.avtalia[cambrinth]['cap']].min
    end
    UserVars.avtalia[cambrinth]['time_seen'] = Time.now
  end

  def choose_avtalia(charge_needed, mana_percentage)
    camb_to_use = UserVars.avtalia.select { |_camb, data| data['time_seen'] && data['cap'] && data['mana'] }
                          .select { |_camb, data| Time.now - data['time_seen'] < 600.0 }
                          .select { |_camb, data| (data['mana'].to_f / data['cap'].to_f) * 100 >= mana_percentage }
                          .select { |_camb, data| data['mana'] > charge_needed / 10 }
                          .max_by { |_camb, data| data['mana'] }

    return camb_to_use ? camb_to_use : {}
  end

  # Determine the numerical range of a Warrior Mage's elemental charge.
  # This can be used to know if the mage is ready to perform certain abilities, like barrage.
  # Returns a number between 0 (no charge) and 11 (max charge).
  # https://elanthipedia.play.net/Summoning_skill#Charge_levels
  def check_elemental_charge
    return 0 unless DRStats.warrior_mage?

    charge_levels = [
      /^You sense nothing out of the ordinary.  Only magic could detect the useless trace of .* still in your system.$/,
      /^A small charge lingers within your body, just above the threshold of perception.$/,
      /^A small charge lingers within your body.$/,
      /^A charge dances through your body.$/,
      /^A charge dances just below the threshold of discomfort.$/,
      /^A charge circulates through your body, causing a low hum to vibrate through your bones.$/,
      /^Elemental essence floats freely within your body, leaving little untouched.$/,
      /^Elemental essence has infused every inch of your body.  While you could contain more, you'd do so at the risk of your health.$/,
      /^Extraplanar power crackles within your body, leaving you feeling mildly feverish.$/,
      /^Extraplanar power crackles within your body, leaving you feeling acutely ill.$/,
      /^Your body sings and crackles with a barely contained charge, destroying what little cenesthesia you had left.$/,
      /^You have reached the limits of your body's capacity to store a charge.  The laws of the Elemental Plane of .* scream demands upon your physiology, threatening your life.$/
    ]
    result = DRC.bput("pathway sense", *charge_levels)
    charge_levels.find_index { |pattern| pattern =~ result }
  end

  # check which symbiotic research is active
  def perc_symbiotic_research
    case DRC.bput('perceive', /combine the weaves of the (\w+) symbiosis/, /Roundtime/)
    when /combine the weaves of the (\w+) symbiosis/
      Regexp.last_match(1)
    else
      nil
    end
  end

  # release symbiotic research
  def release_magical_research
    2.times { DRC.bput("release symbiosis", "Are you sure", "You intentionally wipe", "But you haven't") }
  end
end
end
end
