{
  schema_version: 3,
  name: "cloud sprite meddler",
  noun: "meddler",
  url: "https://gswiki.play.net/cloud_sprite_meddler",
  picture: "",
  level: 27,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 220,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cloud Forest",
      uids: [3219001..3219038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short bow",
        as: 216
      },
      {
        name: "Wooden mace",
        as: 209
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Sleep (501)",
        cs: 149
      },
      {
        name: "Slow (504)",
        cs: 149
      },
      {
        name: "Unknown",
        cs: 149
      }
    ],
    offensive_spells: [
      {
        name: "Sounds (607)"
      },
      {
        name: "Call Swarm (615)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (156..248),
    ranged: (140..177),
    bolt: (140..177),
    udf: 225,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (78..87),
    sor_td: 104,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 121,
    mjs_td: nil,
    mns_td: 87,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors (601)",
      "Thurfel's Ward (503)"
    ],
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
    skin: nil,
    other: "Weapons",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Diminutive in size and with long, spindly limbs, a cloud sprite meddler has enormous almond-shaped eyes that peer curiously out of a heart-shaped face. Tresses of chestnut brown hair fall in a wild mane to just beneath her shoulders, complementing her nut brown skin."
    ],
    arrival: [
      "Smacking one fist into his opposite hand in a menacing manner, a cloud sprite bully wanders in.",
      "A cloud sprite meddler darts out of the shadows! Gently brushing the foliage aside, a cloud sprite meddler moves {direction}."
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A cloud sprite meddler whispers out a spell that sounds like wind playing through trees."
    ],
    attacks: {
      attack: [
        "A cloud sprite meddler swings in, dropping down from a nearby tree with an expectant look upon {pronoun} face."
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
