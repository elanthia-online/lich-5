{
  schema_version: 3,
  name: "death dirge",
  noun: "dirge",
  url: "https://gswiki.play.net/death_dirge",
  picture: "",
  level: 9,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 95,
  speed: 5,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Plains of Bone",
      uids: [14011001..14011022]
    },
    {
      name: "Vornavian Coast",
      uids: [4202141..4202156]
    },
    {
      name: "The Graveyard",
      uids: [18042..18044, 18048..18052, 2162001..2162015]
    },
    {
      name: "unmapped",
      uids: [18045..18047]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 98
      },
      {
        name: "Black scimitar",
        as: 98
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 53
      },
      {
        name: "Closed fist",
        cs: 49
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (-5..34),
    ranged: (4..17),
    bolt: (4..17),
    udf: (49..67),
    bar_td: 27,
    cle_td: 27,
    emp_td: 27,
    pal_td: (24..27),
    ran_td: 27,
    sor_td: 27,
    wiz_td: 27,
    mje_td: 27,
    mne_td: 27,
    mjs_td: 27,
    mns_td: 27,
    mnm_td: 27,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a black scimitar"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a dirge skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Defender of a battleground long lost in the terrain, the death dirge still maintains its post relentlessly, battling all that would attempt to invade its position. All that seems to remain in its consciousness are the orders to repel all who enter, a task it executes with single-minded fury."
    ],
    arrival: [
      "A sorrowful tune is carried on the breeze.  The wailing grows louder, reaching an excruciating pitch as a death dirge arrives!",
      "A death dirge just arrived."
    ],
    flee: [
      "A death dirge runs {direction}."
    ],
    death: [
      "The death dirge falls to the ground motionless.",
      "The death dirge screams evilly one last time and goes still."
    ],
    decay: [
      "A death dirge turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A death dirge swings {weapon} at you!"
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
