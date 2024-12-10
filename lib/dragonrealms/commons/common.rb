module DRC
  $pause_all_lock ||= Mutex.new
  $safe_pause_lock ||= Mutex.new

  module_function

  # Like `fput` but better because will wait for RT
  # before performing command and do smart retries.
  # Will wait for matching text up to 15 seconds then timeout.
  # Also recovers from some limited failures wherein we want to
  # simply fix the issue and retry the bput, like when we're prone
  # and need to be standing. Complex handling should be done within
  # the calling script.
  def bput(message, *matches)
    options = (matches.shift if matches.first.is_a?(Hash)) || {}
    options['timeout'] ||= 15
    options['ignore_rt'] ||= false

    timeout = options['timeout']
    ignore_rt = options['ignore_rt']
    suppress = options['suppress_no_match']

    if options['debug']
      echo "bput.message=#{message}"
      echo "bput.options=#{options}"
      echo "bput.matches=#{matches}"
    end

    waitrt? unless ignore_rt
    log = []
    matches.flatten!
    matches.map! { |item| item.is_a?(Regexp) ? item : /#{item}/i }
    clear
    put message
    timer = Time.now
    while (response = get?) || (Time.now - timer < timeout)

      if response.nil?
        pause 0.1
        next
      end

      log += [response]

      case response
      when /(?:\.\.\.wait |Wait |\.\.\. wait )([0-9]+)/
        unless ignore_rt
          pause(Regexp.last_match(1).to_i - 0.5)
          waitrt?
          put message
          timer = Time.now
        end
        next
      when /Sorry, you may only type ahead/
        pause 1
        put message
        timer = Time.now
        next
      when /^You can't do that while you are asleep./
        put 'wake'
        put message
        timer = Time.now
        next
      when /^You are a bit too busy performing to do that/, /^You should stop playing before you do that/
        put 'stop play'
        put message
        timer = Time.now
        next
      when /would give away your hiding place/
        release_invisibility
        put 'unhide'
        put message
        timer = Time.now
        next
      when /^You don't seem to be able to move to do that/
        next unless matches.include?(response)
      when /^You are still stunned/
        pause 0.5 while stunned?
        pause 0.5
        put message
        timer = Time.now
        next
      when /^You can't do that while entangled in a web/
        pause 0.5 while webbed?
        pause 0.5
        put message
        timer = Time.now
        next
      when /^You must be standing/, /^You should stand up first/, /^You'll need to stand up first/, /^You can't do that while (sitting|kneeling|lying)/, /^You should be sitting up/, /^You really should be standing to play/, /^After failing to draw a breath for what feels like forever/
        fix_standing
        waitrt?
        put message
        timer = Time.now
        next
      end

      matches.each do |match|
        if (result = response.match(match))
          return result.to_a.first
        end
      end
    end

    unless suppress
      echo "*** No match was found after #{timeout} seconds, dumping info"
      echo "messages seen length: #{log.length}"
      log.reverse.each { |logged_response| echo "message: #{logged_response}" }
      echo "checked against #{matches}"
      echo "for command #{message}"
    end

    ''
  end

  def wait_for_script_to_complete(name, args = [], flags = {})
    verify_script(name)
    script_handle = start_script(name, args.map { |arg| arg.to_s =~ /\s/ ? "\"#{arg}\"" : arg }, flags)
    if script_handle
      pause 2
      pause 0.5 while Script.running.include?(script_handle)
    end
    script_handle
  end

  def can_see_sky?
    # If you are indoors and not able to see the sky.
    inside_no_sky = "That's a bit hard to do while inside."
    # If you are indoors but able to see the sky (e.g. a window or skylight).
    inside_yes_sky = "You glance outside"
    # If you are outdoors.
    outside = "You glance up at the sky"
    # Can we see the sky?
    bput("weather", inside_no_sky, inside_yes_sky, outside) != inside_no_sky
  end

  def forage?(item, tries = 5)
    snapshot = "#{right_hand}#{left_hand}"
    while snapshot == "#{right_hand}#{left_hand}"
      tries > 0 ? tries -= 1 : (return false)
      case bput("forage #{item}", 'Roundtime', 'The room is too cluttered to find anything here', 'You really need to have at least one hand free to forage properly', 'You survey the area and realize that any foraging efforts would be futile')
      when 'The room is too cluttered to find anything here'
        return false unless kick_pile?
      when 'You survey the area and realize that any foraging efforts would be futile'
        return false
      when 'You really need to have at least one hand free to forage properly'
        echo 'WARNING: hands not emptied properly. Stowing...'
        fput('stow right')
      end
      waitrt?
    end
    true
  end

  def collect(item, practice = true)
    messages = [
      'As you rummage around',
      'believe you would probably have better luck trying to find a dragon',
      'if you had a bit more luck',
      'The room is too cluttered',
      'one hand free to properly collect',
      'You are sure you knew',
      'You begin to forage around,',
      'You begin scanning the area before you',
      'You begin exploring the area, searching for',
      'You find something dead and lifeless',
      'You cannot collect anything',
      'you fail to find anything',
      'You forage around but are unable to find anything',
      'You manage to collect a pile',
      'You survey the area and realize that any collecting efforts would be futile',
      'You wander around and poke your fingers',
      'You forage around for a while and manage to stir up a small mound of fire ants!'
    ]

    practicing = "practice" if practice

    case bput("collect #{item} #{practicing}", messages)
    when 'The room is too cluttered'
      return unless kick_pile?

      collect(item)
    end
    waitrt?
  end

  def kick_pile?(item = 'pile')
    fix_standing
    return unless DRRoom.room_objs.any? { |room_obj| room_obj.match?(/pile/) }
    bput("kick #{item}", 'I could not find', 'take a step back and run up to', 'Now what did the .* ever do to you', 'You lean back and kick your feet,') == 'take a step back and run up to'
  end

  def rummage(parameter, container)
    result = DRC.bput("rummage /#{parameter} my #{container}", 'but there is nothing in there like that\.', 'looking for .* and see .*', 'While it\'s closed', 'I don\'t know what you are referring to', 'You feel about', 'That would accomplish nothing')

    case result
    when 'You feel about'
      release_invisibility
      return rummage(parameter, container)
    when 'but there is nothing in there like that.', 'While it\'s closed', 'I don\'t know what you are referring to', 'That would accomplish nothing'
      return []
    end

    text = result.match(/looking for .* and see (.*)\.$/).to_a[1]
    case parameter
    when 'B'
      box_list_to_adj_and_noun(text)
    when 'SC'
      scroll_list_to_adj_and_noun(text)
    else
      list_to_nouns(text)
    end
  end

  def get_skins(container)
    rummage('S', container)
  end

  def get_gems(container)
    rummage('G', container)
  end

  def get_materials(container)
    rummage('M', container)
  end

  # Take a game formatted list "an arrow, silver coins and a deobar strongbox"
  # And return an array ["an arrow", "silver coins", "a deobar strongbox"]
  # is this ever useful compared to the list_to_nouns?
  def list_to_array(list)
    list.strip.split(/(?:,|(?:, |\s)?and\s?)(?:\s?<pushBold\/>\s?)?(?=\s\ba\b|\s\ban\b|\s\bsome\b|\s\bthe\b)/i).reject(&:empty?)
  end

  # Take a game formated list of boxes "a reinforced wooden strongbox and a plain ironwood crate"
  # And return an array ["wooden strongbox", "ironwood crate"]
  def box_list_to_adj_and_noun(list)
    list.strip
        .split($box_regex)
        .reject(&:empty?)
        .select { |item| item =~ $box_regex }
        .map { |box| box.gsub('ironwood', 'iron') } # make all ironwood into iron because "the parser"
  end

  def scroll_list_to_adj_and_noun(list)
    list_to_array(list).map { |entry|
      entry
        .sub(/(an|some|a(?: piece of)?)\s/, '')
        .sub(/\slabeled with.*/, '')
        .sub(/icy blue vellum scroll/, 'icy scroll')
        .sub(/green vellum scroll/, 'green scroll')
        .sub(/fetid antelope vellum/, 'antelope vellum')
        .sub(/papyrus roll/, 'papyrus.roll')
        .sub(/pallid red scroll/, 'pallid scroll')
        .sub(/\s(bark|leaf|ostracon|papyrus|parchment|roll|scroll|tablet|vellum|manuscript)\s.*/, ' \1')
        .sub(/crumpled paper/, 'crumpled')
        .sub(/pale ricepaper/, 'pale')
        .sub(/stormy grey/, 'stormy')
        .sub(/mossy green/, 'mossy')
        .sub(/dark purple/, 'dark')
        .sub(/vibrant red/, 'vibrant')
        .sub(/bright green/, 'bright')
        .sub(/icy blue/, 'blue')
        .sub(/pearl-white silk/, 'silk')
        .sub(/ghostly white/, 'white')
        .sub(/crinkled violet/, 'crinkled')
        .sub(/drawing paper/, 'drawing')
        .strip
    }
  end

  # Take a game formatted list "an arrow, silver coins and a deobar strongbox"
  # And return an array of nouns ["arrow", "coins", "strongbox"]
  def list_to_nouns(list)
    list_to_array(list)
      .map { |long_name| get_noun(long_name) }
      .compact
      .reject { |noun| noun == '' }
  end

  def get_noun(long_name)
    remove_flavor_text(long_name).strip.scan(/[a-z\-']+$/i).first
  end

  def remove_flavor_text(item)
    # link is to online regex expression tester
    # https://regex101.com/r/4lGY6u/13
    item.sub(/\s?\b(?:(?:colorfully and )?(?:artfully|artistically|attractively|beautifully|bl?ack-|cleverly|clumsily|crudely|deeply|delicately|edged|elaborately|faintly|flamboyantly|front-|fully|gracefully|heavily|held|intricately|lavishly|masterfully|plentifully|prominantly|roughly|securely|sewn|shabbily|shadow-|simply|somberly|skillfully|sloppily|starkly|stitched|tied and|tightly|well-)\s?)?(?:accented|accentuated|acid-etched|adorned|affixed|appliqued|assembled|attached|augmented|awash|backed|back-laced|balanced|banded|batiked|beaded|bearded|bearing|bedazzled|bedecked|bejeweled|beset|bestrewn|blazoned|bordered|bound|braided|branded|brocaded|bristling|brushed|buckled|burned|buttoned|caked|camouflaged|capped|carved|caught|centered|chased|chiseled|cinched|circled|clasped|cloaked|closed|coated|cobbled together|coiled|colored|composed|concealed|connected|constructed|countoured|covered|crafted|crested|crisscrossed|crowded|crowned|cuffed|cut|dangling|dappled|decked|decorated|deformed|depicting|designed|detailed|discolored|displaying|divided|done|dotted|draped|drawn|dressed|drizzled|dusted|edged|elaborately|embedded|embell?ished|emblazed|emblazoned|embossed|embroidered(?: all over| painstakingly)?|enameled(?: across)?|encircled|encrusted|engraved|engulfed|enhanced|entwined|equipped|etched|fashioned(?: so)?|fastened|feathered|featuring|festooned|fettered|filed|filled|firestained|fit|fitted|fixed|flecked|fletched|forged|formed|framed|fringed|frosted|full|gathered|gleaming|glimmering|glittering|goldworked|growing|gypsy-set|hafted|hand-tooled|hanging|heavily(?:-beaded| covered)?|held fast|hemmed|hewn|hideously|highlighted|hilted|honed|hung|impressed|incised|ingeniously repurposed|inscribed|inlaid|inset|interlaced|interspersed|interwoven|jeweled|joined|laced(?: up)?|lacquered|laden|layered|limned|lined|linked|looped|knotted|made|marbled|marked|marred|meshed|mosaicked|mottled|mounted|oiled|oozing|outlined|ornamented|overlai(?:d|n)|padded|painted|paired|patched|pattern-welded|patterned|pinned|plumed|polished|printed|reinforced|reminiscent|rendered|revealing|riddled|ridged|rimed|ringed|riveted|sashed|scarred|scattered|scorched|sculpted|sealed|seamed|secured|securely|set|sewn|shaped|shimmering|shod|shot|shrouded|side-laced|slashed|slung|smeared|smudged|spangled|speckled|spiraled|splatter-dyed|splattered|spotted|sprinkled|stacked|surmounted|surrounded|suspended|stained|stamped|starred|stenciled|stippled|stitched(?: together)?|strapped|streaked|strengthened|strewn|striated|striped|strung|studded|swathed|swirled|tailored|tangled|tapered|tethered|textured|threaded|tied|tightly|tinged|tinted|tipped|tooled|topped|traced|trimmed|twined|veined|vivified|washed|webbed|weighted|whorled|worked|worn|woven|wrapped|wreathed|wrought)?\b ["]?\b(?:a hand-tooled|across|along|an|around|atop|bearing|belted|bright streaks|dangling|designed|detailing|down (?:each leg|one side)|dyed (?:a|and|deep|of|in|night|rust|shimmering|the|to|with)|engravings|entitled|errant pieces|featuring|flaunting|frescoed|from|Gnomish Pride|(?:encased |quartered )?in(?: the)?|into|labeled|leading|like|lining|matching|(?<!stick|slice|chunk|flask|hunk|series|set|pair|piece) of|on|out|overlayed gleaming silver|resembling|shades of color|sporting|surrounding|that|the|through|tinged somber black|titled|to|upon|WAR MONGER|with|within|\b(?:at|bearing|(?:accented |held |secured )?by|carrying|clutching|colored|cradling|dangling|depicting|(?:prominently )?displaying|embossed|etched|featuring|for(?:ming)?|holding|(?<!slice |chunk |flask |hunk |series |set |pair |piece )of|over|patterned|striped|suspending|textured|that)\b \b(?:a (?:band|beaded|brass|cascade|cluster|coral|crown|dead|.+ (?:ingot|boulder|stone|rock|nugget)|fierce|fanged|fringe|glowing|golden|grinning|howling|large|lotus|mosaic|pair|poorly|rainbow|roaring|row|silver(?:y|weave)?|small|snarling|spray|tailored|thick|tiny|trio|turquoise|yellowed)|(?:squared )?agonite (?:links|decorated)|alternating|an|(?:purple |blue )?and|ash|beaded fringe|blackened (?:steel(?: accents| bearing| with|$)|ironwood)|blue (?:gold|steel)|burnished golden|cascading layers|carved ivory|chain-lined|chitinous|(?:deep red|dull black|pale blue) cloth|cloudberry blossoms|colorful tightly|cotton candy|crimson steel|crisscrossed|curious design|curved|crystaline charm|dark (?:blue|green|grey|metals|windsteel) (?:and|exuding|glaes|hues|khor'vela|muracite|pennon|with)|dark supple|deepest|deeply blending|delicate|dusky (?:dreamweave|green-grey)|ebonwood$|emblazoned|enamel?led (?:steel|bronze)|etched|fine(?:-grained| black| crushed)|finely wrought|flame-kissed|forest|fused-together|fuzzy grey|gauze atop|gilded steel|glass eyeballs|glistening green|golden oak|grey fur|hammered|haralun|has|heavy (?:grey|pearl|silver)|horn|Ilithi cedar|inky black|interlocking silver|interwoven|iridescent|jagged interlocking plates|(?:soft dark|supple|thick|woven) (?:bolts|leather)|lightweight|long swaths|lustrous|kertig ravens|made|metal cogs|mirror-finished|mottled|multiple woods|naphtha|oak|oblong sanguine|one|onyx buttons|opposing images|overlapping|pale cerulean|pallid links|pastel-hued|pins|pitted (?:black iron|steel)|plush velvet|polished (?:bronze|hemlock|steel)|raccoon tails|ram's horns|rat pelts|raw|red and blue|rich (?:purple|golden)|riveted bindings|roughened|rowan|sanguine thornweave|scattered star|scorch marks|sculpted|shadows|shark cartilage|shifting (?:celadon|shades)|shipboard|(?:braided |cobalt |deep black |desert-tan |dusky red Taisidon |ebony |exquisite spider|fine leaf-green |flowing night|glimmering ebony |heavy |marigold |pale gold marquisette and virid |rich copper |spiral-braided |steel|unadorned black Musparan )?silk(?:cress)?|(?:coiled |shimmering )?silver(?:steel| and |y)?|sirese blue spun glitter|six crossed|slender|small bones|smoothly interlocking|snow leopard|soft brushed|somber black|sprawled|sun-bleached|steel links|stones|strips of|sunny yellow|teardrop plates|telothian|the|tiny (?:golden|indurium|scales|skull)|tightly braided|tomiek|torn|twists|two|undyed|vibrant multicolored|viscous|waves of|weighted|well-cured|white ironwood|windstorm gossamer|wintry faeweave|woven diamondwood))\b.*/, '')
  end

  # Items class. Name is the noun of the object. Leather/metal boolean. Is the item worn (defaults to true). Does it hinder lockpicking? (false)
  # Item.new(name:'gloves', leather:true, worn:true, hinders_locks:true, adjective:'ring', bound:true)
  class Item
    attr_accessor :name, :leather, :worn, :hinders_lockpicking, :container, :swappable, :tie_to, :adjective, :bound, :wield, :transforms_to, :transform_verb, :transform_text, :lodges, :skip_repair, :ranged, :needs_unloading

    def initialize(name: nil, leather: nil, worn: false, hinders_locks: nil, container: nil, swappable: false, tie_to: nil, adjective: nil, bound: false, wield: false, transforms_to: nil, transform_text: nil, transform_verb: nil, lodges: true, skip_repair: false, ranged: nil, needs_unloading: nil)
      @name = name
      @leather = leather
      @worn = worn
      @hinders_lockpicking = hinders_locks
      @container = container
      @swappable = swappable
      @tie_to = tie_to
      @adjective = adjective
      @bound = bound
      @wield = wield
      @transforms_to = transforms_to
      @transform_verb = transform_verb
      @transform_text = transform_text
      @lodges = lodges.nil? ? true : lodges
      @skip_repair = skip_repair
      @ranged = ranged.nil? ? ranged_weapon?(name) : ranged
      @needs_unloading = needs_unloading.nil? ? @ranged : needs_unloading
    end

    def short_name
      @adjective ? "#{@adjective}.#{@name}" : @name
    end

    def short_regex
      @adjective ? /\b#{adjective}.*\b#{@name}/i : /\b#{@name}/i
    end

    def ranged_weapon?(noun)
      # Common ranged weapon names
      return true if noun =~ /^(bow|shortbow|longbow|crossbow|stonebow|latchbow|slurbow|lockbow|pelletbow|arbalest|sling|slingshot|blowgun)$/i
      # Gamgweth or racial ranged weapon names
      # https://elanthipedia.play.net/Genie_racial_language_item_subs
      # https://elanthipedia.play.net/Category:Language_Book
      return true if noun =~ /^(jranoki|uku'uan|uku'uanstaho|chunenguti|hhr'ibu|guti|mahil|taisgwelduan|chyeb|sverfil|tangara|alaer|kari|wami|usus|srigos|href|vrope|falocisana|stof|dzelt)$/i

      # Not a ranged weapon we're aware of
      return false
    end

    # Convenience method to parse the text of an item as shown when in your hands, with or without an adjective,
    # into an Item class instance. Originally designed to support DRCI and equipmanager methods.
    def self.from_text(text)
      text = text
             .sub('.', ' ') # convert 'foo.bar' => 'foo bar' so more easily split into adjective and noun
             .squeeze(' ') # condense repeated runs of whitespace with a single space
             .strip # remove leading/trailing whitespace
      parts = text.split
      if text.nil? || text.empty?
        nil
      elsif parts.size > 1
        DRC::Item.new(adjective: parts.first, name: parts.last)
      else
        DRC::Item.new(name: text)
      end
    end
  end

  # Looks up the canonical name of the town based on the given text.
  # Utility to help identify the canonical town name based on arbitrary text.
  # For example, "Theren" for "Therenborough" and "Haven" for "Riverhaven".
  # It also handles missing apostrophes and the occasional space between names
  # like "merkresh" or "Mer'Kresh" or "ainghazal" or "Ain Ghazal".
  # Returns nil if unable to find a match.
  def get_town_name(text)
    towns = $HOMETOWN_REGEX_MAP.select { |_town, regex| regex =~ text }.keys
    if towns.length > 1
      DRC.message("Found multiple towns that match '#{text}': #{towns}")
      DRC.message("Using first town that matched: #{towns.first}")
      DRC.message("To avoid ambiguity, please use the town's full name: https://elanthipedia.play.net/Category:Cities")
    end
    towns.first
  end

  # windows only I believe.
  def beep
    echo("\a")
  end

  def fix_standing
    loop do
      break if standing?

      bput('stand', 'You stand', 'You are so unbalanced', 'As you stand', 'You are already', 'weight of all your possessions', 'You are overburdened and cannot', 'You\'re unconscious', 'You swim back up into a vertical position', "You don't seem to be able to move to do that", 'prevents you from standing', 'You\'re plummeting to your death', 'There\'s no room to do much of anything here')
    end
  end

  def listen?(teacher, observe_flag = false)
    return false if teacher.nil?
    return false if teacher.empty?

    bad_classes = %w[Thievery Sorcery]
    bad_classes += ['Life Magic', 'Holy Magic', 'Lunar Magic', 'Elemental Magic', 'Arcane Magic', 'Targeted Magic', 'Arcana', 'Attunement'] if DRStats.barbarian? || DRStats.thief?
    bad_classes += ['Utility'] if DRStats.barbarian?

    observe = observe_flag ? 'observe' : ''

    case bput("listen to #{teacher} #{observe}", 'begin to listen to \w+ teach the .* skill', 'already listening', 'could not find who', 'You have no idea', 'isn\'t teaching a class', 'don\'t have the appropriate training', 'Your teacher appears to have left', 'isn\'t teaching you anymore', 'experience differs too much from your own', 'but you don\'t see any harm in listening', 'invitation if you wish to join this class', 'You cannot concentrate to listen to .* while in combat')
    when /begin to listen to \w+ teach the (.*) skill/
      return true if bad_classes.grep(/#{Regexp.last_match(1)}/i).empty?

      bput('stop listening', 'You stop listening')
    when 'already listening'
      return true
    when 'but you don\'t see any harm in listening'
      bput('stop listening', 'You stop listening')
    end

    false
  end

  def assess_teach
    case bput('assess teach', 'is teaching a class', 'No one seems to be teaching', 'You are teaching a class')
    when 'No one seems to be teaching', 'You are teaching a class'
      waitrt?
      return {}
    end
    results = reget(20, 'is teaching a class')
    waitrt?

    results.each_with_object({}) do |line, hash|
      line.match(/(.*) is teaching a class on (.*) which is still open to new students/) do |match|
        teacher = match[1]
        skill = match[2]
        # Some classes match the first format, some have additional text in the 'skill' string that needs to be filtered
        skill.match(/.* \(compared to what you already know\) (.*)/) { |m| skill = m[1] }
        hash[teacher] = skill
      end
    end
  end

  def hide?(hide_type = 'hide')
    unless hiding?
      case bput(hide_type, 'Roundtime', 'too busy performing', 'can\'t see any place to hide yourself', 'Stalk what', 'You\'re already stalking', 'Stalking is an inherently stealthy', 'You haven\'t had enough time', 'You search but find no place to hide')
      when 'too busy performing'
        bput('stop play', 'You stop playing', 'In the name of')
        return hide?(hide_type)
      when "You're already stalking"
        put 'stop stalk'
        return hide?(hide_type)
      when 'You haven\'t had enough time'
        pause 1
        return hide?(hide_type)
      end
      pause
      waitrt?
    end
    hiding?
  end

  def fix_dr_bullshit(string)
    return string if string.split.length <= 2

    string.sub!(' and chain', '') if string =~ /ball and chain/

    string =~ /(\S+) .* (\S+)/
    "#{Regexp.last_match(1)} #{Regexp.last_match(2)}"
  end

  def left_hand
    GameObj.left_hand.name == 'Empty' ? nil : fix_dr_bullshit(GameObj.left_hand.name)
  end

  def right_hand
    GameObj.right_hand.name == 'Empty' ? nil : fix_dr_bullshit(GameObj.right_hand.name)
  end

  def left_hand_noun
    GameObj.left_hand == 'Empty' ? nil : GameObj.left_hand.noun
  end

  def right_hand_noun
    GameObj.right_hand == 'Empty' ? nil : GameObj.right_hand.noun
  end

  def release_invisibility
    get_data('spells')
      .spell_data
      .select { |_name, properties| properties['invisibility'] }
      .select { |name, _properties| DRSpells.active_spells.keys.include?(name) }
      .map { |_name, properties| properties['abbrev'] }
      .each { |abbrev| fput("release #{abbrev}") }

    # handle khri silence as it's not part of base-spells data, and method of ending it differs from spells
    bput('khri stop silence', 'You attempt to relax') if DRSpells.active_spells.keys.include?('Khri Silence')
  end

  def check_encumbrance(refresh = true)
    encumbrance = DRStats.encumbrance
    if refresh
      encumbrance_pattern = /(?:Encumbrance)\s:\s(?<encumbrance>.*)/
      case bput('encumbrance', encumbrance_pattern)
      when encumbrance_pattern
        encumbrance = Regexp.last_match[:encumbrance]
      end
    end
    $ENC_MAP[encumbrance]
  end

  def retreat(ignored_npcs = [])
    return if (DRRoom.npcs - ignored_npcs).empty?

    escape_messages = [
      /You are already as far away as you can get/,
      /You retreat from combat/,
      /You sneak back out of combat/,
      /Retreat to where/,
      /There's no place to retreat to/
    ]

    retreat_messages = [
      /retreat/,
      /sneak/,
      /grip on you/,
      /grip remains solid/,
      /You try to back/,
      /You must stand first/,
      /You stop advancing/,
      /You are already/
    ]

    loop do
      case DRC.bput("retreat", *escape_messages, *retreat_messages)
      when *escape_messages
        return true
      else
        DRC.fix_standing
      end
    end
  end

  def text2num(text_num)
    text_num = text_num.tr('-', ' ')
    split_words = text_num.split(' ')
    g = 0

    split_words.each do |word|
      x = $NUM_MAP.fetch(word, nil)
      if word.eql?('hundred') && (g != 0)
        g *= 100
      elsif x.nil?
        echo 'Unknown number'
        return nil
      else
        g += x
      end
    end

    g
  end

  def play_song?(settings, song_list, worn = true, skip_clean = false, climbing = false, skip_tuning = false)
    instrument = worn ? settings.worn_instrument : settings.instrument

    if UserVars.instrument.nil?
      message("No previous instrument setting detected. Cleaning stored song data.")
      UserVars.song = nil
      UserVars.climbing_song = nil
      UserVars.instrument = instrument
    elsif UserVars.instrument != instrument
      message("New instrument #{instrument} detected; old instrument: #{UserVars.instrument}. Resetting stored song data.")
      UserVars.song = nil
      UserVars.climbing_song = nil
      UserVars.instrument = instrument
    end
    UserVars.song = song_list.first.first unless UserVars.song
    UserVars.climbing_song = song_list.first.first unless UserVars.climbing_song
    song_to_play = climbing ? UserVars.climbing_song : UserVars.song
    play_command = "play #{song_to_play}"
    if instrument
      play_command = play_command + " on my #{instrument}"
    end
    fput('release ecry') if DRSpells.active_spells["Eillie's Cry"].to_i > 0
    result = bput(play_command, 'too damaged to play', 'dirtiness may affect your performance', 'slightest hint of difficulty', 'fumble slightly', /Your .+ is submerged in the water/, 'You begin a', 'You struggle to begin', 'You\'re already playing a song', 'You effortlessly begin', 'You begin some', 'You cannot play', 'Play on what instrument', 'Are you sure that\'s the right instrument', 'now isn\'t the best time to be playing', 'Perhaps you should find somewhere drier before trying to play', 'You should stop practicing', /^You really need to drain/, /Your .* tuning is off, and may hinder your performance/)
    case result
    when 'Play on what instrument', 'Are you sure that\'s the right instrument'
      snapshot = "#{right_hand}#{left_hand}"
      fput("get #{instrument}")
      return false if snapshot == "#{right_hand}#{left_hand}"

      fput("wear #{instrument}") if worn
      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    when 'now isn\'t the best time to be playing', 'Perhaps you should find somewhere drier before trying to play', 'You should stop practicing'
      false
    when 'You\'re already playing a song'
      fput('stop play')
      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    when 'You cannot play'
      wait_for_script_to_complete('safe-room')
    when /Your .* tuning is off, and may hinder your performance/
      DRC.message("Instrument out of tune. Attempting to tune it.")
      return true if DRSkill.getrank('Performance') < 20
      return true if skip_tuning
      return true unless DRC.tune_instrument(settings)

      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    when 'dirtiness may affect your performance', /^You really need to drain/
      return true if DRSkill.getrank('Performance') < 20
      return true if skip_clean
      return true unless clean_instrument(settings, worn)

      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    when 'slightest hint of difficulty', 'fumble slightly'
      true
    when 'You begin a', 'You effortlessly begin', 'You begin some'
      return true if song_to_play == song_list.to_a.last.last
      # Ignore difficulty messages if we have an offset
      return true if climbing && UserVars.climbing_song_offset

      stop_playing
      UserVars.climbing_song = song_list[UserVars.climbing_song] || song_list.first.first if climbing
      UserVars.song = song_list[UserVars.song] || song_list.first.first unless climbing
      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    when 'You struggle to begin'
      return true if song_to_play == song_list.first.first
      # Ignore difficulty messages if we have an offset
      return true if climbing && UserVars.climbing_song_offset

      stop_playing
      UserVars.climbing_song = song_list.first.first if climbing
      UserVars.song = song_list.first.first unless climbing
      play_song?(settings, song_list, worn, skip_clean, climbing, skip_tuning)
    else
      false
    end
  end

  def stop_playing
    bput('stop play', 'You stop playing your song', 'In the name of', "But you're not performing")
  end

  def clean_instrument(settings, worn = true)
    cloth = settings.cleaning_cloth
    instrument = worn ? settings.worn_instrument : settings.instrument

    unless DRCI.get_item?(cloth)
      DRC.message('You have no chamois cloth -- this could cause problems with playing an instrument!')
      DRC.beep
      return false
    end
    DRC.stop_playing

    if worn
      unless DRCI.remove_item?(instrument)
        DRC.message("Could not remove #{instrument} putting away cloth, and not trying to clean.")
        DRCI.stow_item?(cloth)
        DRC.beep
        return false
      end
    else
      unless DRCI.get_item?(instrument)
        DRC.message("Could not get #{instrument} putting away cloth, and not trying to clean.")
        DRCI.stow_item?(cloth)
        DRC.beep
        return false
      end
    end

    loop do
      case DRC.bput("wipe my #{instrument} with my #{cloth}", 'Roundtime', 'not in need of drying', 'You should be sitting up')
      when 'not in need of drying'
        break
      when 'You should be sitting up'
        DRC.fix_standing
        next
      end
      pause 1
      waitrt?

      until /you wring a dry/i =~ DRC.bput("wring my #{cloth}", 'You wring a dry', 'You wring out')
        pause 1
        waitrt?
      end
    end

    until /not in need of cleaning/i =~ DRC.bput("clean my #{instrument} with my #{cloth}", 'Roundtime', 'not in need of cleaning')
      pause 1
      waitrt?
    end

    DRCI.wear_item?(instrument) if worn
    DRCI.stow_item?(cloth)
    true
  end

  def tune_instrument(settings)
    instrument = settings.worn_instrument || settings.instrument

    unless instrument
      DRC.message("Neither worn_instrument, nor instrument set. Doing nothing.")
      return false
    end

    DRC.stop_playing

    unless (DRC.left_hand.nil? && DRC.right_hand.nil?) || DRCI.in_hands?(instrument)
      DRC.message("Need two free hands. Not tuning now.")
      return false
    end

    if settings.worn_instrument
      unless DRCI.remove_item?(instrument) || DRCI.in_hands?(instrument)
        DRC.message("Could not remove #{instrument}. Not trying to tune.")
        DRC.beep
        return false
      end
    else
      unless DRCI.get_item?(instrument) || DRCI.in_hands?(instrument)
        DRC.message("Could not get #{instrument}. Not trying to tune.")
        DRC.beep
        return false
      end
    end
    DRC.do_tune(instrument)
    waitrt?
    pause 1
    DRCI.wear_item?(instrument) if settings.worn_instrument
    true
  end

  def do_tune(instrument, tuning = "")
    unless instrument && DRCI.in_hands?(instrument)
      DRC.message("No instrument found in hands. Not trying to tune.")
      DRC.beep
      return false
    end

    case DRC.bput("tune my #{instrument} #{tuning}",
                  /^You should be sitting up/,
                  /After a moment, you .* flat/,
                  /After a moment, you .* sharp/,
                  /After a moment, you .* tune/)
    when /After a moment, you .* tune/
      DRC.message("Instrument tuned.")
      return true
    when /After a moment, you .* flat/
      DRC.do_tune(instrument, "sharp")
    when /After a moment, you .* sharp/
      DRC.do_tune(instrument, "flat")
    when /^You should be sitting up/
      DRC.fix_standing
      DRC.do_tune(instrument)
    end
  end

  def pause_all
    return false unless $pause_all_lock.try_lock

    @pause_all_no_unpause = []

    Script.running.find_all(&:paused?).each do |script|
      @pause_all_no_unpause << script
    end

    Script.running.find_all do |script|
      !script.paused? &&
        !script.no_pause_all &&
        script != Script.current
    end
          .each(&:pause)

    pause 1
    true
  end

  def unpause_all
    return false unless $pause_all_lock.owned?

    Script.running.find_all do |script|
      script.paused? &&
        !@pause_all_no_unpause.include?(script)
    end
          .each(&:unpause)

    @pause_all_no_unpause = []
    $pause_all_lock.unlock

    true
  end

  def smart_pause_all
    paused_script_list = []
    Script.running.find_all { |s| !s.paused? && !s.no_pause_all && s.name != Script.self.name }.each do |s|
      s.pause
      paused_script_list << s.name
    end
    echo("Pausing #{paused_script_list} to run #{Script.self.name}")
    return paused_script_list
  end

  def unpause_all_list(scripts_to_unpause)
    echo("Unpausing #{scripts_to_unpause}, #{Script.self.name} has finished.")
    Script.running.find_all { |s| s.paused? && !s.no_pause_all && scripts_to_unpause.include?(s.name) }.each(&:unpause)
  end

  def safe_pause_list
    return false unless $safe_pause_lock.try_lock

    paused_script_list = []
    Script.running.find_all { |s| !s.paused? && !s.no_pause_all && s.name != Script.self.name }.each do |s|
      s.pause
      paused_script_list << s.name
    end
    echo("Pausing #{paused_script_list} to run #{Script.self.name}")
    return paused_script_list
  end

  def safe_unpause_list(scripts_to_unpause)
    return false unless $safe_pause_lock.owned?

    echo("Unpausing #{scripts_to_unpause}, #{Script.self.name} has finished.")
    Script.running.find_all { |s| s.paused? && !s.no_pause_all && scripts_to_unpause.include?(s.name) }.each(&:unpause)
    $safe_pause_lock.unlock
  end

  def set_stance(skill)
    div = if DRStats.guild == 'Paladin'
            50
          elsif %w[Barbarian Ranger Trader Commoner].include?(DRStats.guild)
            60
          else
            70
          end

    points = 80 + DRSkill.getrank('Defending') / div
    secondary = points > 100 ? 100 : points
    tertiary = points > 100 ? points - 100 : 0

    stance = case skill.downcase
             when 'parry'
               "100 #{secondary} #{tertiary}"
             when 'shield'
               "100 #{tertiary} #{secondary}"
             else
               "100 #{secondary} #{tertiary}"
             end

    DRC.bput("stance set #{stance}", /Setting your/)
  end

  # Sends a message to the atmospherics window.
  # By default the message is bold.
  # DEPRECATED in favor of log_window
  def atmo(text, make_bold = true)
    log_window(text, "atmospherics", make_bold)
  end

  # Sends a message to the specified window. Replaces the deprecated atmo method.
  # By default the message is bold. Creates window upon request. Pre-clears window upon request.
  def log_window(text, window_name, make_bold = true, create_window = false, pre_clear_window = false)
    if create_window
      _respond("<streamWindow id=\"#{window_name}\" title=\"#{window_name}\" location=\"center\" save=\"true\" />")
      _respond("<exposeStream id=\"#{window_name}\"/>")
    end

    if pre_clear_window
      _respond("<clearStream id=\"#{window_name}\"/>\r\n")
    end

    _respond(
      "<pushStream id=\"#{window_name}\"/>" + (make_bold ? bold(text) : text),
      "<popStream id=\"#{window_name}\" /><prompt time=\"#{XMLData.server_time.to_i}\">&gt;</prompt>"
    )
  end

  # Helper function to wrap text in the necessary markup
  # to make it render as bold in a frontend client.
  # This method has little use to other scripts and is designed for
  # `atmo` and `message` methods in common.lic.
  def bold(text)
    string = ''

    $fake_stormfront ? string.concat("\034GSL\r\n ") : string.concat("<pushBold\/>")

    string.concat(text)

    $fake_stormfront ? string.concat("\034GSM\r\n ") : string.concat("<popBold\/>")

    string
  end

  # Sends a message to the game window.
  # By default the message is bold.
  def message(text, make_bold = true)
    string = ''
    if text.index('\n')
      text.split('\n').each { |line| string.concat("#{line}") }
    else
      string.concat(text)
    end
    _respond(make_bold ? bold(string) : string)
  end
end
