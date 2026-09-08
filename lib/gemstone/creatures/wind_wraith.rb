{
  schema_version: 3,
  name: "wind wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/wind_wraith",
  picture: "",
  level: 63,
  family: "Wraith",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Dark Palisade",
      uids: [3040004..3040015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 294
      },
      {
        name: "Claw",
        as: (300..303)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Claw",
        cs: 291
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
    melee: (231..450),
    ranged: (208..284),
    bolt: (208..284),
    udf: (230..534),
    bar_td: nil,
    cle_td: (247..259),
    emp_td: (250..259),
    pal_td: (208..217),
    ran_td: (211..220),
    sor_td: (256..265),
    wiz_td: nil,
    mje_td: (276..284),
    mne_td: (276..284),
    mjs_td: (247..250),
    mns_td: (247..250),
    mnm_td: (183..189),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: true,
    boxes: false,
    skin: nil,
    other: [
      "a small glowing vial",
      "essence of air"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The wind wraith is a miniature windstorm all unto itself. Heavy air currents swirl around the wind wraith, obscuring its form and making it much more difficult to hit the elusive creature. The wind wraith bobs and weaves within the gusting air streams, directing them to maximum effect against its foes. The only part of the wind wraith that seems easy to see is its crimson, glowing eyes, which appear to float steadily despite the thunderous winds around it."
    ],
    arrival: [],
    flee: [
      "A wind wraith drifts {direction}.",
      "A flexile wind wraith drifts {direction}.",
      "A dazzling wind wraith drifts {direction}.",
      "A flashy wind wraith drifts {direction}.",
      "A wind wraith storms about, causing small tornado-like spirals to break off from {pronoun} form in various directions."
    ],
    death: [
      "A wind wraith releases a groan of mingled ecstasy and relief as it fades away.",
      "A flexile wind wraith releases a groan of mingled ecstasy and relief as it fades away.",
      "A sinuous wind wraith releases a groan of mingled ecstasy and relief as it fades away.",
      "A dazzling wind wraith releases a groan of mingled ecstasy and relief as it fades away.",
      "A flashy wind wraith releases a groan of mingled ecstasy and relief as it fades away.",
      "A robust wind wraith releases a groan of mingled ecstasy and relief as it fades away."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A wind wraith rushes past you, causing your clothing to ripple wildy in the strong winds."
      ],
      claw: [
        "A wind wraith claws at you!"
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
    triggers: {},
    frenzy: "A wind wraith whales away, consumed with bloodlust!"
  }
}
