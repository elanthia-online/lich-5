{
  schema_version: 3,
  name: "tusked ursian",
  noun: "ursian",
  url: "https://gswiki.play.net/tusked_ursian",
  picture: "",
  level: 37,
  family: "Bear",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 260,
  speed: 7,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13031001..13031010, 13031025..13031043, 13031071..13031080]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (200..260)
      },
      {
        name: "Charge (attack)",
        as: 260
      },
      {
        name: "Bite",
        as: 260
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Squeal"
      },
      {
        name: "Lash"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (118..216),
    ranged: (124..161),
    bolt: (151..161),
    udf: (227..283),
    bar_td: 111,
    cle_td: (113..120),
    emp_td: (120..126),
    pal_td: (108..114),
    ran_td: (111..114),
    sor_td: (126..135),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 142,
    mjs_td: (120..129),
    mns_td: (120..129),
    mnm_td: 111,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "an ursian tusk",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing nearly nine feet in height, the tusked ursian appears to be an unnatural union between a boar and a bear. Her yellow-tusked maw is lined with jagged fangs and beady eyes peer over a moist snout. Powerful limbs ending in black-nailed claws attest to the ferocity of this beast."
    ],
    arrival: [
      "A tusked ursian lumbers in!"
    ],
    flee: [
      "A tusked ursian slowly lumbers {direction}, growling in pain.",
      "A tusked ursian lumbers {direction}."
    ],
    death: [
      "The tusked ursian collapses heavily into a heap on the ground and dies.",
      "The tusked ursian lets out a blood-curdling roar and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A tusked ursian claws at you!"
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
