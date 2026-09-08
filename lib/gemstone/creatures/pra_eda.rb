{
  schema_version: 3,
  name: "pra'eda",
  noun: "pra'eda",
  url: "https://gswiki.play.net/pra'eda",
  picture: "",
  level: 29,
  family: "Canine",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 341,
  speed: nil,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4214303..4214323, 4218101..4218121]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 281
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Energy Maelstrom (710)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "18N",
    immunities: [],
    melee: (119..241),
    ranged: (52..177),
    bolt: (52..177),
    udf: (152..235),
    bar_td: 89,
    cle_td: (105..118),
    emp_td: (115..125),
    pal_td: (98..107),
    ran_td: (89..99),
    sor_td: (103..128),
    wiz_td: nil,
    mje_td: (109..130),
    mne_td: (109..130),
    mjs_td: (114..131),
    mns_td: (114..131),
    mnm_td: (107..117),
    defensive_spells: [
      "Elemental Defense III (414)",
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
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed left arm",
    "a completely severed right arm"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glimmering blue essence shard",
      "t'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The pra'eda before you stands on two legs, but the golden eyes that glare from either side of its fanged, canine snout and its coat of grizzled fur make it difficult to determine whether it is more human or wolf in nature. A stench of blood and rotting flesh emanates from its fanged jaws, and its rough, tattered clothing is stained with dirt and gore."
    ],
    arrival: [],
    flee: [
      "A pra'eda runs {direction}.",
      "A pra'eda limps {direction}."
    ],
    death: [
      "The pra'eda falls to the ground motionless.",
      "The pra'eda cries out one last time and lies still."
    ],
    decay: [
      "A pra'eda decays away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [
      "A pra'eda growls out an ancient incantation."
    ],
    attacks: {
      attack: [
        "A pra'eda swings {weapon} at you!",
        "A pra'eda throw back {pronoun} head and howls!",
        "A pra'eda points {pronoun} hands at you!"
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
