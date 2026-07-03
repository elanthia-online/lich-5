{
  schema_version: 3,
  name: "animated slush",
  noun: "",
  url: "https://gswiki.play.net/animated_slush",
  picture: "",
  level: 54,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Gossamer Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: "(icy appendage) 288 - 298"
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 291
      }
    ],
    warding_spells: [
      {
        name: "Torment (718)",
        cs: 127
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Slush wall"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: (242..250),
    udf: nil,
    bar_td: (185..197),
    cle_td: 202,
    emp_td: 192,
    pal_td: nil,
    ran_td: nil,
    sor_td: 212,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 223,
    mjs_td: nil,
    mns_td: 200,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "Gold Dust"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>An animated slush could easily be mistaken for a huge pile of snow that has partially melted then refrozen.  It presents a squat, icy white cone ten feet wide at the base but only rising five feet high.  The edges are slightly transparent and tinged a light blue, while the interior is dark, with portions seeming more solid than others.  Rippling over the terrain, its exact motion indiscernible, the animated slush unerringly finds its prey, yet it displays no sensory glands of any type.</pre>"
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
