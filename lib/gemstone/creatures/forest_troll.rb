{
  schema_version: 3,
  name: "forest troll",
  noun: "troll",
  url: "https://gswiki.play.net/forest_troll",
  picture: "",
  level: 14,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 190,
  speed: 14,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [14001..14023, 15001..15030, 16005..16035]
    },
    {
      name: "Vornavian Coast",
      uids: [4214101..4214115]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: (173..201)
      },
      {
        name: "Scimitar",
        as: 173
      },
      {
        name: "Bite",
        as: 153
      },
      {
        name: "Claw",
        as: 153
      },
      {
        name: "Dagger",
        as: 173
      },
      {
        name: "Flail",
        as: 173
      },
      {
        name: "Mace",
        as: 173
      },
      {
        name: "War mattock",
        as: 173
      },
      {
        name: "Unknown",
        as: 201
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
    melee: (45..151),
    ranged: (33..100),
    bolt: (33..100),
    udf: (99..117),
    bar_td: 49,
    cle_td: 57,
    emp_td: 57,
    pal_td: (54..57),
    ran_td: 57,
    sor_td: 53,
    wiz_td: nil,
    mje_td: (42..49),
    mne_td: (42..49),
    mjs_td: (42..63),
    mns_td: (42..63),
    mnm_td: (42..49),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Troll Regeneration",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a cudgel",
    "a dagger",
    "a flail",
    "a leather breastplate",
    "a mace",
    "a scimitar",
    "a war hammer",
    "a war mattock",
    "a wooden shield",
    "some full leather",
    "some light leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll hide",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the forest troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence."
    ],
    arrival: [
      "A forest troll just arrived!",
      "A forest troll ambles in."
    ],
    flee: [
      "A forest troll heads {direction}."
    ],
    death: [
      "The forest troll screams one last time and dies.",
      "The forest troll falls to the ground and dies."
    ],
    decay: [
      "A forest troll decays into compost."
    ],
    search: [],
    spell_prep: [
      "A forest troll mutters, \"Srlarloror'rt srar 'mrosrdnragh srar 'r'rar s'r'vr'r'rawrd!\""
    ],
    attacks: {
      attack: [
        "A forest troll swings {weapon} at you!",
        "A forest troll throws {pronoun} head back and howls!",
        "A forest troll swings a scimitar at {target}!"
      ],
      bite: [
        "A forest troll tries to bite you!"
      ],
      claw: [
        "A forest troll claws at you!"
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
