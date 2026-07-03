{
  schema_version: 3,
  name: "forest troll",
  noun: "",
  url: "https://gswiki.play.net/forest_troll",
  picture: "",
  level: 14,
  family: "Troll",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 190,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Upper Trollfang",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 173
      },
      {
        name: "Scimitar",
        as: 173
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Attack strength]] boost (howl)"
      },
      {
        name: "[[Attack strength]] boost (snarl)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: 58,
    ranged: 45,
    bolt: 70,
    udf: 195,
    bar_td: 49,
    cle_td: nil,
    emp_td: 57,
    pal_td: nil,
    ran_td: nil,
    sor_td: 53,
    wiz_td: nil,
    mje_td: (42..49),
    mne_td: (42..49),
    mjs_td: (42..57),
    mns_td: (42..57),
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll hide",
    other: "[[small troll tooth]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Huge and dangerous, the forest troll towers above even a tall giantman.  Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones.  A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter.  No light of intellect glows in its narrow piggish eyes.  The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.</pre>"
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
