# frozen_string_literal: true

module Lich
  module DragonRealms
    DR_LEARNING_RATES = [
      'clear',
      'dabbling',
      'perusing',
      'learning',
      'thoughtful',
      'thinking',
      'considering',
      'pondering',
      'ruminating',
      'concentrating',
      'attentive',
      'deliberative',
      'interested',
      'examining',
      'understanding',
      'absorbing',
      'intrigued',
      'scrutinizing',
      'analyzing',
      'studious',
      'focused',
      'very focused',
      'engaged',
      'very engaged',
      'cogitating',
      'fascinated',
      'captivated',
      'engrossed',
      'riveted',
      'very riveted',
      'rapt',
      'very rapt',
      'enthralled',
      'nearly locked',
      'mind lock'
    ].freeze

    # Length of the longest learning rate name, used for padding in exp display
    DR_LONGEST_LEARNING_RATE_LENGTH = DR_LEARNING_RATES.max_by(&:length).length

    DR_BALANCE_VALUES = [
      'completely',
      'hopelessly',
      'extremely',
      'very badly',
      'badly',
      'somewhat off',
      'off',
      'slightly off',
      'solidly',
      'nimbly',
      'adeptly',
      'incredibly'
    ].freeze

    DR_SKILLS_DATA = {
      skillsets: {
        'Armor'    => [
          'Shield Usage',
          'Light Armor',
          'Chain Armor',
          'Brigandine',
          'Plate Armor',
          'Defending',
          'Conviction'
        ].freeze,
        'Lore'     => [
          'Alchemy',
          'Appraisal',
          'Enchanting',
          'Engineering',
          'Forging',
          'Outfitting',
          'Performance',
          'Scholarship',
          'Tactics',
          'Empathy',
          'Bardic Lore',
          'Trading',
          'Mechanical Lore'
        ].freeze,
        'Weapon'   => [
          'Parry Ability',
          'Small Edged',
          'Large Edged',
          'Twohanded Edged',
          'Small Blunt',
          'Large Blunt',
          'Twohanded Blunt',
          'Slings',
          'Bow',
          'Crossbow',
          'Staves',
          'Polearms',
          'Light Thrown',
          'Heavy Thrown',
          'Brawling',
          'Offhand Weapon',
          'Melee Mastery',
          'Missile Mastery',
          'Expertise'
        ].freeze,
        'Magic'    => [
          'Primary Magic',
          'Arcana',
          'Attunement',
          'Augmentation',
          'Debilitation',
          'Targeted Magic',
          'Utility',
          'Warding',
          'Sorcery',
          'Astrology',
          'Summoning',
          'Theurgy',
          'Inner Magic',
          'Inner Fire',
          'Lunar Magic',
          'Elemental Magic',
          'Holy Magic',
          'Life Magic',
          'Arcane Magic'
        ].freeze,
        'Survival' => [
          'Evasion',
          'Athletics',
          'Perception',
          'Stealth',
          'Locksmithing',
          'Thievery',
          'First Aid',
          'Outdoorsmanship',
          'Skinning',
          'Instinct',
          'Backstab',
          'Thanatology'
        ].freeze
      }.freeze,
      guild_skill_aliases: {
        'Cleric'       => { 'Primary Magic' => 'Holy Magic' }.freeze,
        'Necromancer'  => { 'Primary Magic' => 'Arcane Magic' }.freeze,
        'Warrior Mage' => { 'Primary Magic' => 'Elemental Magic' }.freeze,
        'Thief'        => { 'Primary Magic' => 'Inner Magic' }.freeze,
        'Barbarian'    => { 'Primary Magic' => 'Inner Fire' }.freeze,
        'Ranger'       => { 'Primary Magic' => 'Life Magic' }.freeze,
        'Bard'         => { 'Primary Magic' => 'Elemental Magic' }.freeze,
        'Paladin'      => { 'Primary Magic' => 'Holy Magic' }.freeze,
        'Empath'       => { 'Primary Magic' => 'Life Magic' }.freeze,
        'Trader'       => { 'Primary Magic' => 'Lunar Magic' }.freeze,
        'Moon Mage'    => { 'Primary Magic' => 'Lunar Magic' }.freeze
      }.freeze
    }.freeze

    KRONAR_BANKS = ['Crossings', 'Dirge', 'Ilaya Taipa', 'Leth Deriel'].freeze
    LIRUM_BANKS = ["Aesry Surlaenis'a", "Hara'jaal", "Mer'Kresh", "Muspar'i", 'Ratha', 'Riverhaven', "Rossman's Landing", 'Therenborough', 'Throne City'].freeze
    DOKORA_BANKS = ['Ain Ghazal', 'Boar Clan', "Chyolvea Tayeu'a", 'Hibarnhvidar', 'Fang Cove', "Raven's Point", 'Shard'].freeze

    BANK_TITLES = {
      "Aesry Surlaenis'a" => ['[[Tona Kertigen, Deposit Window]]'].freeze,
      'Ain Ghazal'        => ['[[Ain Ghazal, Private Depository]]'].freeze,
      'Boar Clan'         => ['[[Ranger Guild, Bank]]'].freeze,
      "Chyolvea Tayeu'a"  => ["[[Chyolvea Tayeu'a, Teller]]"].freeze,
      'Crossings'         => ['[[Provincial Bank, Teller]]'].freeze,
      'Dirge'             => ["[[Dirge, Traveller's Bank]]"].freeze,
      'Fang Cove'         => ['[[First Council Banking, Vault]]'].freeze,
      "Hara'jaal"         => ["[[Baron's Forset, Teller]]"].freeze,
      'Hibarnhvidar'      => ['[[Second Provincial Bank of Hibarnhvidar, Teller]]', '[[Hibarnhvidar, Teller Windows]]', '[[First Arachnid Bank, Lobby]]'].freeze,
      'Ilaya Taipa'       => ['[[Ilaya Taipa, Trader Outpost Bank]]'].freeze,
      'Leth Deriel'       => ['[[Imperial Depository, Domestic Branch]]'].freeze,
      "Mer'Kresh"         => ["[[Harti Clemois Bank, Teller's Window]]"].freeze,
      "Muspar'i"          => ["[[Old Lata'arna Keep, Teller Windows]]"].freeze,
      'Ratha'             => ['[[Lower Bank of Ratha, Cashier]]', '[[Sshoi-sson Palace, Grand Provincial Bank, Bursarium]]'].freeze,
      "Raven's Point"     => ["[[Bank of Raven's Point, Depository]]"].freeze,
      'Riverhaven'        => ['[[Bank of Riverhaven, Teller]]'].freeze,
      "Rossman's Landing" => ["[[Traders' Guild Outpost, Depository]]"].freeze,
      'Shard'             => ["[[First Bank of Ilithi, Teller's Windows]]"].freeze,
      'Therenborough'     => ['[[Bank of Therenborough, Teller]]'].freeze,
      'Throne City'       => ['[[Faldesu Exchequer, Teller]]'].freeze
    }.freeze

    VAULT_TITLES = {
      'Crossings'     => ['[[Crossing, Carousel Chamber]]'].freeze,
      'Fang Cove'     => ['[[Fang Cove, Carousel Chamber]]'].freeze,
      'Leth Deriel'   => ['[[Leth Deriel, Carousel Chamber]]'].freeze,
      "Mer'Kresh"     => ["[[Mer'Kresh, Carousel Square]]"].freeze,
      "Muspar'i"      => ["[[Muspar'i, Carousel Square]]"].freeze,
      'Ratha'         => ['[[Ratha, Carousel Square]]'].freeze,
      'Riverhaven'    => ['[[Riverhaven, Carousel Chamber]]'].freeze,
      'Shard'         => ['[[Shard, Carousel Chamber]]'].freeze,
      'Therenborough' => ['[[Therenborough, Carousel Chamber]]'].freeze
    }.freeze

    # Some spells may last for an unknown duration,
    # such as cyclic spells that last as long as
    # the caster can harness mana for it.
    # Or, barbarian abilities when the character
    # doesn't have Power Monger mastery to see true
    # durations but only vague guestimates.
    # In those situations, we set use this value.
    UNKNOWN_DURATION = 1000 unless defined?(UNKNOWN_DURATION)

    HOMETOWN_REGEX_MAP = {
      'Arthe Dale'        => /^(arthe( dale)?)$/i,
      'Crossing'          => /^(cross(ing)?)$/i,
      'Darkling Wood'     => /^(darkling( wood)?)$/i,
      'Dirge'             => /^(dirge)$/i,
      "Fayrin's Rest"     => /^(fayrin'?s?( rest)?)$/i,
      'Leth Deriel'       => /^(leth( deriel)?)$/i,
      'Shard'             => /^(shard)$/i,
      'Steelclaw Clan'    => /^(steel( )?claw( clan)?|SCC)$/i,
      'Stone Clan'        => /^(stone( clan)?)$/i,
      'Tiger Clan'        => /^(tiger( clan)?)$/i,
      'Wolf Clan'         => /^(wolf( clan)?)$/i,
      'Riverhaven'        => /^(river|haven|riverhaven)$/i,
      "Rossman's Landing" => /^(rossman'?s?( landing)?)$/i,
      'Therenborough'     => /^(theren(borough)?)$/i,
      'Langenfirth'       => /^(lang(enfirth)?)$/i,
      'Fornsted'          => /^(fornsted)$/i,
      'Hvaral'            => /^(hvaral)$/i,
      'Ratha'             => /^(ratha)$/i,
      'Aesry'             => /^(aesry)$/i,
      "Mer'Kresh"         => /^(mer'?kresh)$/i,
      'Throne City'       => /^(throne( city)?)$/i,
      'Hibarnhvidar'      => /^(hib(arnhvidar)?)$/i,
      "Raven's Point"     => /^(raven'?s?( point)?)$/i,
      'Boar Clan'         => /^(boar( clan)?)$/i,
      'Fang Cove'         => /^(fang( cove)?)$/i,
      "Muspar'i"          => /^(muspar'?i)$/i,
      'Ain Ghazal'        => /^(ain( )?ghazal)$/i
    }.freeze

    # List of canonical town names, like 'Therenborough' and 'Langenfirth'.
    HOMETOWN_LIST = HOMETOWN_REGEX_MAP.keys.freeze

    # Union of regular expressions that match town names, like /^(theren(borough)?)$/i
    HOMETOWN_REGEX = Regexp.union(HOMETOWN_REGEX_MAP.values)

    ORDINALS = %w[first second third fourth fifth sixth seventh eighth ninth tenth eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth eighteenth nineteenth twentieth].freeze

    CURRENCIES = %w[Kronars Lirums Dokoras].freeze

    ENC_MAP = {
      'None'                              => 0,
      'Light Burden'                      => 1,
      'Somewhat Burdened'                 => 2,
      'Burdened'                          => 3,
      'Heavy Burden'                      => 4,
      'Very Heavy Burden'                 => 5,
      'Overburdened'                      => 6,
      'Very Overburdened'                 => 7,
      'Extremely Overburdened'            => 8,
      'Tottering Under Burden'            => 9,
      'Are you even able to move?'        => 10,
      "It's amazing you aren't squashed!" => 11
    }.freeze

    NUM_MAP = {
      'zero'      => 0,
      'one'       => 1,
      'two'       => 2,
      'three'     => 3,
      'four'      => 4,
      'five'      => 5,
      'six'       => 6,
      'seven'     => 7,
      'eight'     => 8,
      'nine'      => 9,
      'ten'       => 10,
      'eleven'    => 11,
      'twelve'    => 12,
      'thirteen'  => 13,
      'fourteen'  => 14,
      'fifteen'   => 15,
      'sixteen'   => 16,
      'seventeen' => 17,
      'eighteen'  => 18,
      'nineteen'  => 19,
      'twenty'    => 20,
      'thirty'    => 30,
      'forty'     => 40,
      'fifty'     => 50,
      'sixty'     => 60,
      'seventy'   => 70,
      'eighty'    => 80,
      'ninety'    => 90
    }.freeze

    BOX_REGEX = /((?:brass|copper|deobar|driftwood|iron|ironwood|mahogany|oaken|pine|steel|wooden) (?:box|caddy|casket|chest|coffer|crate|skippet|strongbox|trunk))/

    MANA_MAP = {
      'weak'       => %w[dim glowing bright].freeze,
      'developing' => %w[faint muted glowing luminous bright].freeze,
      'improving'  => %w[faint hazy flickering shimmering glowing lambent shining fulgent glaring].freeze,
      'good'       => %w[faint dim hazy dull muted dusky pale flickering shimmering pulsating glowing lambent shining luminous radiant fulgent brilliant flaring glaring blazing blinding].freeze
    }.freeze

    PRIMARY_SIGILS_PATTERN = /\b(?:abolition|congruence|induction|permutation|rarefaction) sigil\b/
    SECONDARY_SIGILS_PATTERN = /\b(?:antipode|ascension|clarification|decay|evolution|integration|metamorphosis|nurture|paradox|unity) sigil\b/

    VOL_MAP = {
      'enormous' => 20,
      'massive'  => 10,
      'huge'     => 5,
      'large'    => 4,
      'medium'   => 3,
      'small'    => 2,
      'tiny'     => 1
    }.freeze

    # Backward compatibility aliases for global variables.
    # Third-party scripts may rely on these globals.
    $HOMETOWN_REGEX_MAP = HOMETOWN_REGEX_MAP
    $HOMETOWN_LIST = HOMETOWN_LIST
    $HOMETOWN_REGEX = HOMETOWN_REGEX
    $ORDINALS = ORDINALS
    $CURRENCIES = CURRENCIES
    $ENC_MAP = ENC_MAP
    $NUM_MAP = NUM_MAP
    $box_regex = BOX_REGEX
    $MANA_MAP = MANA_MAP
    $PRIMARY_SIGILS_PATTERN = PRIMARY_SIGILS_PATTERN
    $SECONDARY_SIGILS_PATTERN = SECONDARY_SIGILS_PATTERN
    $VOL_MAP = VOL_MAP
  end
end
