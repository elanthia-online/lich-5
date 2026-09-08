{
  schema_version: 3,
  name: "magna vereri",
  noun: "vereri",
  url: "https://gswiki.play.net/magna_vereri",
  picture: "",
  level: 72,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 400,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Abbey",
      uids: [4132201..4132240, 4132243..4132248]
    },
    {
      name: "unmapped",
      uids: [4132241..4132242]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Repel (Fear)"
      },
      {
        name: "Decaying fists",
        as: 354
      },
      {
        name: "Leather whip",
        as: 363
      },
      {
        name: "Mouth full of rotting teeth",
        as: (327..364)
      },
      {
        name: "Slash",
        as: (354..360)
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Gesture"
      },
      {
        name: "Spellsong"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (320..549),
    ranged: (314..402),
    bolt: (314..402),
    udf: (372..601),
    bar_td: 290,
    cle_td: (301..310),
    emp_td: (297..306),
    pal_td: (263..269),
    ran_td: (254..263),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 328,
    mne_td: 328,
    mjs_td: (254..306),
    mns_td: (254..306),
    mnm_td: (213..222),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a clinging raw silk shift"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A horrific magna vereri is the animated corpse of a woman, twisted into a perverse parody of beauty. Glowing white eyes glare out of a face whose cheeks are rouged with streaks of blood, and the lips are bloated and red around needle-like teeth. The obscene curvature of her body is at odds with her skeletal limbs, which are little more than bones clad in pale blue-grey corpseflesh. The vereri's movements are jerky and uneven as she totters around, driven by feral rage."
    ],
    arrival: [
      "A horrific magna vereri just arrived from some lichen-clad dark wooden docks.",
      "A horrific magna vereri just arrived from a torchlit overgrown grotto."
    ],
    flee: [
      "A horrific magna vereri crawls {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "Screaming out an insensate series of curses, a horrific magna vereri pounds at you with {pronoun} decaying fists!",
        "A magna vereri gnashes at you with a mouth full of rotting teeth!",
        "Screeching with mindless rage, a magna vereri slashes at you with maggot-gnawed talons!"
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
