{
  schema_version: 3,
  name: "krolvin mercenary",
  noun: "mercenary",
  url: "https://gswiki.play.net/krolvin_mercenary",
  picture: "",
  level: 17,
  family: "Krolvin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 200,
  speed: 10,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Sea Caves",
      uids: [26103..26120]
    },
    {
      name: "Lysierian Hills",
      uids: [93050..93070]
    },
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250050..4250068]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 178
      },
      {
        name: "Unknown",
        as: 178
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Cheapshot"
      },
      {
        name: "Stomp"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (109..224),
    ranged: (91..140),
    bolt: (91..140),
    udf: 127,
    bar_td: 51,
    cle_td: (45..57),
    emp_td: (51..59),
    pal_td: (48..57),
    ran_td: (45..51),
    sor_td: (51..57),
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (51..57),
    mns_td: (51..57),
    mnm_td: (51..57),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a handaxe",
    "a reinforced shield",
    "some brigandine armor",
    "some burnished arm greaves",
    "some double leather",
    "some studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as the average human, the mercenary has the characteristic long-fingered hands and sturdy musculature that denote most of the krolvin race. The mercenary also sports the trademark grey-blue skin and thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
    ],
    arrival: [
      "A krolvin mercenary just arrived.",
      "A krolvin mercenary leaps into the room!",
      "A krolvin mercenary leaps into the area!"
    ],
    flee: [
      "A krolvin mercenary stumps {direction}.",
      "A krolvin mercenary just went through a high opening."
    ],
    death: [
      "The krolvin mercenary rolls over on the ground and goes still.",
      "The krolvin mercenary rolls over on the floor and goes still.",
      "A krolvin mercenary collapses into a pile of dirty rags."
    ],
    decay: [
      "A krolvin mercenary collapses into a pile of dirty rags."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A krolvin mercenary tries to stomp on you, but misses!"
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
