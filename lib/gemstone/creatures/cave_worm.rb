{
  schema_version: 3,
  name: "cave worm",
  noun: "",
  url: "https://gswiki.play.net/cave_worm",
  picture: "",
  level: 10,
  family: "Worm",
  type: "Worm",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Mine Road",
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
        name: "Ensnare",
        as: 139
      },
      {
        name: "Bite",
        as: 129
      },
      {
        name: "Charge (attack)",
        as: 139
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (90..146),
    ranged: nil,
    bolt: 58,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: nil,
    mns_td: nil,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "The cave worm is a colorless and legless serpentine creature. Its bizarre head is encircled with six three-foot horns, which cut through obstacles as it moves through subterranean caverns. Over 20 feet in length, it feeds on both rock and flesh, and caustic acid oozes from its body and its 10-foot prehensile tongue. Six-inch fangs allow it to casually tear through any armor, and its pungent acid dissolves what it cannot consume."
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
