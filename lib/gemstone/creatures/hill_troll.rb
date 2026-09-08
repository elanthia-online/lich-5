{
  schema_version: 3,
  name: "hill troll",
  noun: "troll",
  url: "https://gswiki.play.net/hill_troll",
  picture: "",
  level: 16,
  family: "troll",
  type: "biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: true,
  boss_type: nil,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 210,
  speed: 13,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Hidden Vale",
      uids: [36006..36010]
    },
    {
      name: "Upper Trollfang",
      uids: [17001..17010, 374001..374012]
    },
    {
      name: "unmapped",
      uids: [21001..21006]
    },
    {
      name: "Slope",
      uids: [395017..395051]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword"
      },
      {
        name: "War mattock"
      },
      {
        name: "War hammer"
      },
      {
        name: "Spear"
      },
      {
        name: "Cudgel",
        as: 207
      },
      {
        name: "Military pick",
        as: 194
      },
      {
        name: "Unknown",
        as: 182
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Attack strength boost (bellow)"
      },
      {
        name: "Attack strength boost - (snarl)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (111..234),
    ranged: (108..189),
    bolt: (108..189),
    udf: (128..130),
    bar_td: 55,
    cle_td: 63,
    emp_td: 63,
    pal_td: (60..63),
    ran_td: 63,
    sor_td: 59,
    wiz_td: nil,
    mje_td: 55,
    mne_td: 55,
    mjs_td: 63,
    mns_td: 63,
    mnm_td: (48..55),
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
    "a cudgel",
    "a reinforced shield",
    "a war hammer",
    "some arm greaves",
    "some full leather",
    "some leather boots",
    "some studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll beard",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the hill troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.\n\nAppraisal:\nThe hill troll is large in size, about nine feet high in her current state, appears to be of hardy constitution, is in an offensive stance, and is in relatively good shape."
    ],
    arrival: [
      "A hill troll just arrived!"
    ],
    flee: [
      "A hill troll heads {direction}."
    ],
    death: [
      "The hill troll screams one last time and dies.",
      "The hill troll falls to the ground and dies."
    ],
    decay: [
      "A hill troll decays into compost."
    ],
    search: [
      "A hill troll sniffs around looking for something."
    ],
    spell_prep: [
      "A hill troll mutters, \"Sr'r'wr'ralars 'ght lorlur'ra larlor'rikr.\""
    ],
    attacks: {
      attack: [
        "A hill troll swings {weapon} at you!",
        "A hill troll throws {pronoun} head back and bellows!",
        "A hill troll swings a twohanded sword at {target}!"
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
