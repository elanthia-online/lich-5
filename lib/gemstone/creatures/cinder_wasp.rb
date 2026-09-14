{
  schema_version: 3,
  name: "cinder wasp",
  noun: "wasp",
  url: "https://gswiki.play.net/cinder_wasp",
  picture: "",
  level: 46,
  family: "Wasp",
  type: "Insect",
  undead: false,
  blood: true,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 260,
  speed: 6,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Volcano",
      uids: [3052001..3052025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stinger (attack)",
        as: 276
      },
      {
        name: "Stinger",
        as: 276
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
    melee: (197..247),
    ranged: (206..255),
    bolt: (206..255),
    udf: 273,
    bar_td: 203,
    cle_td: 218,
    emp_td: 217,
    pal_td: (191..198),
    ran_td: 198,
    sor_td: 226,
    wiz_td: nil,
    mje_td: (235..236),
    mne_td: (235..236),
    mjs_td: (225..228),
    mns_td: (225..228),
    mnm_td: 198,
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
    "a completely severed left leg"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a shimmering wasp wing",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "With a body length of nearly 1 foot, and a wingspan of 18 inches, a cinder wasp is without a doubt, the biggest wasp to be seen. The body is black with irridescent blue highlights. The wings are like soap bubbles, clear with rainbows of color shimmering across them. Large redly glowing compound eyes and a stinger large enough to make a nasty stiletto give this creature a distinctly threatening appearance."
    ],
    arrival: [
      "A cinder wasp just arrived.",
      "A cinder wasp weaves slowly as it flies in.",
      "A cinder wasp wobbles as it flies in."
    ],
    flee: [
      "A cinder wasp heads {direction}.",
      "A cinder wasp wobbles {direction}."
    ],
    death: [
      "The cinder wasp flutters its wings one last time and dies.",
      "The cinder wasp twitches violently, then dies."
    ],
    decay: [
      "A cinder wasp decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A cinder wasp stabs at you with {pronoun} stinger!"
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
