{
  schema_version: 3,
  name: "mountain troll",
  noun: "troll",
  url: "https://gswiki.play.net/mountain_troll",
  picture: "",
  level: 17,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 200,
  speed: 14,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Hidden Vale",
      uids: [36006..36010, 40001..40013, 40020..40020]
    },
    {
      name: "unmapped",
      uids: [40014..40019]
    },
    {
      name: "Noralgar Forest",
      uids: [4286002..4286013, 4286046..4286067]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 190
      },
      {
        name: "Military pick",
        as: 190
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Attack strength boost (howl)"
      },
      {
        name: "Attack strength boost (snarl)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (62..183),
    ranged: (35..94),
    bolt: 90,
    udf: (108..113),
    bar_td: 58,
    cle_td: 66,
    emp_td: 66,
    pal_td: (63..66),
    ran_td: 36,
    sor_td: 62,
    wiz_td: nil,
    mje_td: (51..58),
    mne_td: (51..58),
    mjs_td: 96,
    mns_td: 96,
    mnm_td: (51..58),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Health regeneration",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed left arm",
    "a flail",
    "a leather helm",
    "a sigil-etched glaes flail",
    "some brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "troll toe",
    other: [
      "small troll tooth",
      "s'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the mountain troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence."
    ],
    arrival: [
      "A mountain troll just arrived!",
      "A mountain troll just arrived.",
      "A mountain troll ambles in."
    ],
    flee: [
      "A mountain troll runs {direction}."
    ],
    death: [
      "The mountain troll screams one last time and dies.",
      "The mountain troll falls to the ground and dies.",
      "The mountain troll twitches violently, then dies."
    ],
    decay: [
      "A mountain troll decays into compost."
    ],
    search: [
      "A mountain troll sniffs around looking for something."
    ],
    spell_prep: [
      "A mountain troll mutters, \"Srlarloror'rt srar 'mrosrdnragh srar 'r'rar s'r'vr'r'rawrd!\"",
      "A mountain troll mutters, \"Gr'r'r'ra.\"",
      "A mountain troll mutters, \"Dnuor'rg 'ght ot noirtrid'dra larghufr'r'ruoloro ar karmri slur'riar'rtn ruo.\""
    ],
    attacks: {
      attack: [
        "A mountain troll swings {weapon} at you!",
        "A mountain troll throws {pronoun} head back and howls!"
      ]
    },
    info: {
      general: [],
      class_tips: {
        cleric: [],
        paladin: [],
        ranger: [],
        bard: [],
        wizard: [],
        empath: [],
        rogue: [],
        warrior: [],
        sorcerer: []
      },
      miscellany: []
    },
    triggers: {}
  }
}
