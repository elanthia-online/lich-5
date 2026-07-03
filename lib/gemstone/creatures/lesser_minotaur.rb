{
  schema_version: 3,
  name: "lesser minotaur",
  noun: "",
  url: "https://gswiki.play.net/lesser_minotaur",
  picture: "",
  level: 74,
  family: "Minotaur",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehntoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Greataxe",
        as: (381..405)
      },
      {
        name: "Waraxe",
        as: 376
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Bull Rush"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: 263,
    ranged: 260,
    bolt: nil,
    udf: nil,
    bar_td: (239..251),
    cle_td: (254..269),
    emp_td: (239..264),
    pal_td: (210..234),
    ran_td: nil,
    sor_td: (261..282),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (288..297),
    mjs_td: (249..264),
    mns_td: (249..264),
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur hide",
    other: "[[Tiny golden seed]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The lesser minotaur is an ugly, brutish looking beast.  Taller than most average men, the minotaur has a bull-like appearance while his muscular body is humanoid with thick arms and broad shoulders.  The lesser minotaur feet end in hooves that rattle the ground with every step.  Despite his barbaric features, a great intelligence is reflected in the depths of his eyes and mannerisms.</pre>"
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
