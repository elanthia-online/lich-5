{
  schema_version: 3,
  name: "Ilvari sprite",
  noun: "sprite",
  url: "https://gswiki.play.net/ilvari_sprite",
  picture: "",
  level: 72,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Red Forest",
      uids: [480231..480245, 17006231..17006245]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bone Shatter (1106)",
        cs: (306..315)
      },
      {
        name: "Repel (Fear)",
        cs: (306..315)
      },
      {
        name: "Wither (1115)",
        cs: (306..315)
      },
      {
        name: "Sympathy (1120)"
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Dispel (119)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (341..440),
    ranged: (250..445),
    bolt: (250..445),
    udf: (413..519),
    bar_td: nil,
    cle_td: (295..304),
    emp_td: (294..303),
    pal_td: (251..260),
    ran_td: (266..269),
    sor_td: (300..315),
    wiz_td: nil,
    mje_td: (319..338),
    mne_td: (319..338),
    mjs_td: (294..303),
    mns_td: (294..303),
    mnm_td: (235..241),
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Wall of Force (140)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a leafy green tunic"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The subtle hourglass figure of this tiny offshoot of an elven female is all you can see due to a strange silvery aura covering her. Her face is the exception, for it shows through as a near picture perfect model of beauty. The only spoiler in the package is the strange look of madness in her shimmering silver eyes."
    ],
    arrival: [],
    flee: [
      "An Ilvari sprite shudders and limps {direction}."
    ],
    death: [
      "The Ilvari sprite's eyes grow dim as her lifeforce fades away."
    ],
    decay: [
      "The layer of bark on an Ilvari sprite hardens and absorbs the attack!  The bark crackles as it crumbles to dust.",
      "The layer of bark on an Ilvari sprite hardens and absorbs the magical energy!  The bark crackles as it crumbles to dust."
    ],
    search: [
      "An Ilvari sprite sheds a tear as {pronoun} glances around apprehensively."
    ],
    spell_prep: [
      "An Ilvari sprite concentrates intently on you, and a pulse of pearlescent energy ripples toward you!",
      "An Ilvari sprite closes {pronoun} eyes in deep concentration..."
    ],
    attacks: {
      attack: [
        "An Ilvari sprite blows a kiss at you!",
        "An Ilvari sprite blows a handful of twinkling dust at you!",
        "An Ilvari sprite blows a handful of chalky dust at you!"
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
