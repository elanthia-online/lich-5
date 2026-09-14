{
  schema_version: 3,
  name: "mud wasp",
  noun: "wasp",
  url: "https://gswiki.play.net/mud_wasp",
  picture: "",
  level: 38,
  family: "Wasp",
  type: "Insect",
  undead: false,
  blood: true,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 262,
  speed: 7,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Fhorian Village",
      uids: [3030011..3030023, 3030225..3030234, 3030250..3030255]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stinger (attack)",
        as: 254
      },
      {
        name: "Stinger",
        as: 254
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
    asg: "8N",
    immunities: [],
    melee: (210..250),
    ranged: (184..252),
    bolt: (184..252),
    udf: 238,
    bar_td: 174,
    cle_td: 123,
    emp_td: (180..184),
    pal_td: (171..174),
    ran_td: 174,
    sor_td: (131..191),
    wiz_td: nil,
    mje_td: (138..198),
    mne_td: (138..198),
    mjs_td: (183..184),
    mns_td: (183..184),
    mnm_td: 174,
    defensive_spells: [],
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
    "a completely severed left foreleg",
    "a completely severed left hind leg",
    "a completely severed left leg",
    "a completely severed right leg"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a wasp stinger",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "With a body about the size of a human hand, and a wingspan approaching a foot, the mud wasp is a rather intimidating sight. It is a superb example of camouflage, with a brown body covered in splatters of mud, and eyes the color of muddy water. The wings are the only exception to the brown color scheme, being transparent with a faint touch of blue."
    ],
    arrival: [
      "A mud wasp just arrived.",
      "A mud wasp wobbles as it flies in.",
      "A mud wasp weaves slowly as it flies in."
    ],
    flee: [
      "A mud wasp heads {direction}.",
      "A mud wasp wobbles {direction}.",
      "A mud wasp just went into a warehouse.",
      "A mud wasp just went across a footbridge.",
      "A mud wasp just went into a storage building."
    ],
    death: [
      "The mud wasp flutters its wings one last time and dies.",
      "The mud wasp twitches violently, then dies."
    ],
    decay: [
      "A mud wasp decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mud wasp stabs at you with {pronoun} stinger!"
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
