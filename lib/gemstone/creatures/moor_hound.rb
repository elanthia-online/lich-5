{
  schema_version: 3,
  name: "moor hound",
  noun: "hound",
  url: "https://gswiki.play.net/moor_hound",
  picture: "",
  level: 33,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: 8,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Shattered Moors",
      uids: [420001..420037, 420040..420046]
    },
    {
      name: "unmapped",
      uids: [420038..420039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 232
      },
      {
        name: "Charge",
        as: 242
      },
      {
        name: "Claw",
        as: (232..242)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Wing Buffet"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (199..233),
    ranged: (162..222),
    bolt: (162..222),
    udf: (238..277),
    bar_td: 101,
    cle_td: (109..115),
    emp_td: (113..122),
    pal_td: (96..99),
    ran_td: (99..108),
    sor_td: 119,
    wiz_td: nil,
    mje_td: (124..133),
    mne_td: (124..133),
    mjs_td: 113,
    mns_td: 113,
    mnm_td: (99..108),
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
    skin: "moor hound paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The moor hound stands nearly as tall as a halfling, her broad shoulders easily support the weight of her frame. The jet-black fur is matted and frizzled, giving the hound an unkept appearance. Tiny droplets of perspiration drip from her blood-red eyes as misty vapor wafts out of the nostrils. A curl in her upper lip forms, revealing a massive canine tooth as she hungrily looks upon her pray."
    ],
    arrival: [
      "A moor hound stalks into the area with a sickly vapor pouring from {pronoun} nostrils!",
      "A moor hound stalks into the room with a sickly vapor pouring from {pronoun} nostrils!",
      "A moor hound stalks into the area with a sickly vapor pouring from {pronoun} {weapon}!",
      "A moor hound stalks into the room with a sickly vapor pouring from {pronoun} {weapon}!"
    ],
    flee: [
      "A moor hound plods {direction}.",
      "A spiny moor hound plods {direction}."
    ],
    death: [
      "The moor hound falls to the ground and dies.",
      "The moor hound rolls over and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A moor hound shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    attacks: {
      claw: [
        "A moor hound claws at you!"
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
