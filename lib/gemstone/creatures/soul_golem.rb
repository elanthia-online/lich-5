{
  schema_version: 3,
  name: "soul golem",
  noun: "golem",
  url: "https://gswiki.play.net/soul_golem",
  picture: "",
  level: 63,
  family: "Golem",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: nil,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 500,
  speed: 9,
  height: nil,
  size: "",
  areas: [
    {
      name: "Dark Palisade",
      uids: [3041016..3041025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (attack)",
        as: 337
      },
      {
        name: "Ensnare (attack)",
        as: 353
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Twin Hammerfists"
      }
    ],
    special_abilities: [
      {
        name: "Foot slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "19N",
    immunities: [],
    melee: 176,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: (250..253),
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A fiercely sculptured reptilian head curves sinuously into a rigid glaes body. A mixture of ophidian grace and rock hard volcanic glass with the impassive frigidity of both, the soul golem radiates power and malice. Standing about eight feet tall and four feet wide at the shoulder, its massive frame dominates the area. Within the chest of the golem, a pure white mist is frozen solid in the glass, pulsing with a sickly glow. As a contrast to the frozen horror of its chest, its soulstone eyes flare with a brilliant viridian light."
    ],
    arrival: [],
    flee: [],
    death: [
      "The soul golem falls to the floor dead, {pronoun} husk still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A soul golem pounds at you with {pronoun} glaes gauntleted left fist!",
        "A soul golem pounds at you with {pronoun} glaes gauntleted right fist!",
        "A soul golem tries to ensnare you in {pronoun} solid glaes arms!"
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
