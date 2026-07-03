{
  schema_version: 3,
  name: "frost giant",
  noun: "",
  url: "https://gswiki.play.net/frost_giant",
  picture: "",
  level: 38,
  family: "Giant",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Frozen Battlefield",
      rooms: []
    },
    {
      name: "Glatoph",
      rooms: []
    },
    {
      name: "Olbin Pass",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War hammer",
        as: (234..259)
      },
      {
        name: "Battle axe",
        as: 251
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: (177..222)
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Stomp"
      }
    ],
    special_abilities: [
      {
        name: "AS Boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (162..236),
    ranged: 187,
    bolt: 201,
    udf: nil,
    bar_td: 109,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (134..151),
    wiz_td: nil,
    mje_td: 139,
    mne_td: 145,
    mjs_td: nil,
    mns_td: 135,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
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
    skin: "a giant toe",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Standing more than twice as tall as the tallest giantman, the frost giant trails frost and snow in his wake.  Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the frost giant's dull white frost-covered skin.</pre>"
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
