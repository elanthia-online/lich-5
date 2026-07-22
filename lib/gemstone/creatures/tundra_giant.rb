{
  schema_version: 3,
  name: "tundra giant",
  noun: "",
  url: "https://gswiki.play.net/tundra_giant",
  picture: "",
  level: 34,
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
  max_hp: 480,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Frozen Battlefield",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 235
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 193
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 216,
    ranged: nil,
    bolt: 133,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (121..139),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 141,
    mjs_td: nil,
    mns_td: 133,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
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
    skin: "a tundra giant tooth",
    other: "Glimmering blue essence shard"
  },
  messaging: {
    description: [
      "Standing twice as tall as as the tallest giantman, the ice giant trails frost and snow in its wake. Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the ice giant's dull white frost-covered skin."
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
