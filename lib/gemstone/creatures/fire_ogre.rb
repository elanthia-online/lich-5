{
  schema_version: 3,
  name: "fire ogre",
  noun: "ogre",
  url: "https://gswiki.play.net/fire_ogre",
  picture: "",
  level: 28,
  family: "Ogre",
  type: "Biped",
  undead: false,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 225,
  speed: nil,
  height: 10,
  size: "huge",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023001..3023028]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 245
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 167
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17N",
    immunities: [],
    melee: (102..205),
    ranged: (92..126),
    bolt: (102..126),
    udf: (178..281),
    bar_td: (101..115),
    cle_td: (95..105),
    emp_td: (101..109),
    pal_td: (74..83),
    ran_td: (82..89),
    sor_td: (104..111),
    wiz_td: nil,
    mje_td: (113..137),
    mne_td: (113..137),
    mjs_td: (114..124),
    mns_td: (114..124),
    mnm_td: (86..95),
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a deep black spiked flail",
    "a scorched black oak-hafted flail"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: "ogre tooth",
    other: "shimmering blue essence shardessence of fire",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Easily three times as large as the largest giantman, this brutish creature glares about with fire red eyes. The fire ogre has black, soot-covered skin and fiery orange hair. Steam pours from her nose as she flexes her massive claws."
    ],
    arrival: [
      "A fire ogre stomps in, covered in black soot!"
    ],
    flee: [
      "A fire ogre stomps {direction}, leaving a trail of black soot."
    ],
    death: [],
    decay: [
      "A fire ogre burns down to a husk, that crumbles to ash."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A fire ogre blows {pronoun} fiery breath at you!"
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
