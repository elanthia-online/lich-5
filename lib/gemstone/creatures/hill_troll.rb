{
  schema_version: 3,
  name: "hill troll",
  noun: "",
  url: "https://gswiki.play.net/hill_troll",
  picture: "",
  level: 16,
  family: "troll",
  type: "biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Environs",
      rooms: []
    },
    {
      name: "Hidden Vale",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword",
        as: (182..214)
      },
      {
        name: "War mattock",
        as: (182..214)
      },
      {
        name: "War hammer",
        as: (182..214)
      },
      {
        name: "Spear",
        as: (182..214)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "[[Attack strength]] boost (bellow)"
      },
      {
        name: "[[Attack strength]] boost - (snarl)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (118..204),
    ranged: 108,
    bolt: (130..160),
    udf: 133,
    bar_td: 55,
    cle_td: 63,
    emp_td: 63,
    pal_td: nil,
    ran_td: nil,
    sor_td: 59,
    wiz_td: nil,
    mje_td: 55,
    mne_td: 55,
    mjs_td: 63,
    mns_td: 63,
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
    skin: "a troll beard",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Huge and dangerous, the hill troll towers above even a tall giantman.  Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones.  A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter.  No light of intellect glows in its narrow piggish eyes.  The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.</pre>\n\nAppraisal:\n<pre{{log2}}>The hill troll is large in size, about nine feet high in her current state, appears to be of hardy constitution, is in an offensive stance, and is in relatively good shape.</pre>"
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
