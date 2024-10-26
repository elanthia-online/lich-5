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
]

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
]

DR_SKILLS_DATA = {
  "skillsets": {
    "Armor": [
      "Shield Usage",
      "Light Armor",
      "Chain Armor",
      "Brigandine",
      "Plate Armor",
      "Defending",
      "Conviction"
    ],
    "Lore": [
      "Alchemy",
      "Appraisal",
      "Enchanting",
      "Engineering",
      "Forging",
      "Outfitting",
      "Performance",
      "Scholarship",
      "Tactics",
      "Empathy",
      "Bardic Lore",
      "Trading",
      "Mechanical Lore"
    ],
    "Weapon": [
      "Parry Ability",
      "Small Edged",
      "Large Edged",
      "Twohanded Edged",
      "Small Blunt",
      "Large Blunt",
      "Twohanded Blunt",
      "Slings",
      "Bow",
      "Crossbow",
      "Staves",
      "Polearms",
      "Light Thrown",
      "Heavy Thrown",
      "Brawling",
      "Offhand Weapon",
      "Melee Mastery",
      "Missile Mastery",
      "Expertise"
    ],
    "Magic": [
      "Primary Magic",
      "Arcana",
      "Attunement",
      "Augmentation",
      "Debilitation",
      "Targeted Magic",
      "Utility",
      "Warding",
      "Sorcery",
      "Astrology",
      "Summoning",
      "Theurgy",
      "Inner Magic",
      "Inner Fire",
      "Lunar Magic",
      "Elemental Magic",
      "Holy Magic",
      "Life Magic",
      "Arcane Magic"
    ],
    "Survival": [
      "Evasion",
      "Athletics",
      "Perception",
      "Stealth",
      "Locksmithing",
      "Thievery",
      "First Aid",
      "Outdoorsmanship",
      "Skinning",
      "Instinct",
      "Backstab",
      "Thanatology"
    ]
  },
  "guild_skill_aliases": {
    "Cleric": {
      "Primary Magic": "Holy Magic"
    },
    "Necromancer": {
      "Primary Magic": "Arcane Magic"
    },
    "Warrior Mage": {
      "Primary Magic": "Elemental Magic"
    },
    "Thief": {
      "Primary Magic": "Inner Magic"
    },
    "Barbarian": {
      "Primary Magic": "Inner Fire"
    },
    "Ranger": {
      "Primary Magic": "Life Magic"
    },
    "Bard": {
      "Primary Magic": "Elemental Magic"
    },
    "Paladin": {
      "Primary Magic": "Holy Magic"
    },
    "Empath": {
      "Primary Magic": "Life Magic"
    },
    "Trader": {
      "Primary Magic": "Lunar Magic"
    },
    "Moon Mage": {
      "Primary Magic": "Lunar Magic"
    }
  }
}

KRONAR_BANKS = ['Crossings', 'Dirge', 'Ilaya Taipa', 'Leth Deriel']
LIRUM_BANKS = ["Aesry Surlaenis'a", "Hara'jaal", "Mer'Kresh", "Muspar'i", "Ratha", "Riverhaven", "Rossman's Landing", "Therenborough", "Throne City"]
DOKORA_BANKS = ["Ain Ghazal", "Boar Clan", "Chyolvea Tayeu'a", "Hibarnhvidar", "Fang Cove", "Raven's Point", "Shard"]

BANK_TITLES = {
  "Aesry Surlaenis'a" => ["[[Tona Kertigen, Deposit Window]]"],
  "Ain Ghazal"        => ["[[Ain Ghazal, Private Depository]]"],
  "Boar Clan"         => ["[[Ranger Guild, Bank]]"],
  "Chyolvea Tayeu'a"  => ["[[Chyolvea Tayeu'a, Teller]]"],
  "Crossings"         => ["[[Provincial Bank, Teller]]"],
  "Dirge"             => ["[[Dirge, Traveller's Bank]]"],
  "Fang Cove"         => ["[[First Council Banking, Vault]]"],
  "Hara'jaal"         => ["[[Baron's Forset, Teller]]"],
  "Hibarnhvidar"      => ["[[Second Provincial Bank of Hibarnhvidar, Teller]]", "[[Hibarnhvidar, Teller Windows]]", "[[First Arachnid Bank, Lobby]]"],
  "Ilaya Taipa"       => ["[[Ilaya Taipa, Trader Outpost Bank]]"],
  "Leth Deriel"       => ["[[Imperial Depository, Domestic Branch]]"],
  "Mer'Kresh"         => ["[[Harti Clemois Bank, Teller's Window]]"],
  "Muspar'i"          => ["[[Old Lata'arna Keep, Teller Windows]]"],
  "Ratha"             => ["[[Lower Bank of Ratha, Cashier]]", "[[Sshoi-sson Palace, Grand Provincial Bank, Bursarium]]"],
  "Raven's Point"     => ["[[Bank of Raven's Point, Depository]]"],
  "Riverhaven"        => ["[[Bank of Riverhaven, Teller]]"],
  "Rossman's Landing" => ["[[Traders' Guild Outpost, Depository]]"],
  "Shard"             => ["[[First Bank of Ilithi, Teller's Windows]]"],
  "Therenborough"     => ["[[Bank of Therenborough, Teller]]"],
  "Throne City"       => ["[[Faldesu Exchequer, Teller]]"]
}

VAULT_TITLES = {
  "Crossings"     => ["[[Crossing, Carousel Chamber]]"],
  "Fang Cove"     => ["[[Fang Cove, Carousel Chamber]]"],
  "Leth Deriel"   => ["[[Leth Deriel, Carousel Chamber]]"],
  "Mer'Kresh"     => ["[[Mer'Kresh, Carousel Square]]"],
  "Muspar'i"      => ["[[Muspar'i, Carousel Square]]"],
  "Ratha"         => ["[[Ratha, Carousel Square]]"],
  "Riverhaven"    => ["[[Riverhaven, Carousel Chamber]]"],
  "Shard"         => ["[[Shard, Carousel Chamber]]"],
  "Therenborough" => ["[[Therenborough, Carousel Chamber]]"]
}
