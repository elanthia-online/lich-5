{
  schema_version: 3,
  name: "mountain troll",
  noun: "",
  url: "https://gswiki.play.net/mountain_troll",
  picture: "",
  level: 17,
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
  max_hp: 200,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Hidden Vale",
      rooms: []
    },
    {
      name: "Shores of Lough Ne'Halin",
      rooms: []
    },
    {
      name: "Troll Lair",
      rooms: []
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
    melee: (73..175),
    ranged: nil,
    bolt: 90,
    udf: 113,
    bar_td: 58,
    cle_td: 66,
    emp_td: nil,
    pal_td: nil,
    ran_td: 36,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 58,
    mne_td: 58,
    mjs_td: nil,
    mns_td: 66,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "troll toe",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Huge and dangerous, the mountain troll towers above even a tall giantman.  Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones.  A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter.  No light of intellect glows in its narrow piggish eyes.  The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.</pre>"
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
