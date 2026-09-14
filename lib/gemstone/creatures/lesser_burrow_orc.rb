{
  schema_version: 3,
  name: "lesser burrow orc",
  noun: "orc",
  url: "https://gswiki.play.net/lesser_burrow_orc",
  picture: "",
  level: 7,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: 15,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Melgorehn's Valley",
      uids: [2148002..2148024]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: (101..127)
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
    asg: "6",
    immunities: [],
    melee: (42..119),
    ranged: (34..45),
    bolt: (34..45),
    udf: (60..126),
    bar_td: nil,
    cle_td: 21,
    emp_td: (-7..21),
    pal_td: (18..21),
    ran_td: 21,
    sor_td: 21,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
    mjs_td: 21,
    mns_td: 21,
    mnm_td: 21,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc claw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The burrow orc would stand roughly six feet high, were she not stooped over. She is thinner and more gaunt than the land-roaming orcs, with sickly white skin and no hair on her smelly frame. She seems more interested in stuffing herself and protecting her burrow than anything else."
    ],
    arrival: [
      "A lesser burrow orc trudges in, spitting and grunting with every step."
    ],
    flee: [
      "A lesser burrow orc trudges {direction}."
    ],
    death: [],
    decay: [
      "A lesser burrow orc's body crumbles into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser burrow orc swings {weapon} at you!"
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
