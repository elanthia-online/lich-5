{
  schema_version: 3,
  name: "illoke jarl",
  noun: "",
  url: "https://gswiki.play.net/illoke_jarl",
  picture: "",
  level: 89,
  family: "Giant",
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
  max_hp: 600,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Fist",
        as: 371
      },
      {
        name: "Hammer",
        as: 422
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Divine Strike (1615)",
        cs: (363..375)
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Mstrike"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: 270,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 336,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 373,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Divine Shield",
      "Fasthr's Reward",
      "Lesser Shroud",
      "Song of Unravelling (1013)"
    ],
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
    skin: nil,
    other: "radiant crimson essence shard"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>\nThe hulking frame of the Illoke jarl towers high overhead, ready to obliterate any who would intrude upon his territory.  Craggy, deep grey skin sheathes him in a natural armor, with little hindrance to his movements.  A pair of piercing black eyes stare out with contempt, barely distinguishable against his dark complexion.  In contrast, a shimmering crimson symbol of Illoke is chiseled deep into his forehead, radiating a dull red glow.\n</pre>"
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
