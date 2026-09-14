{
  schema_version: 3,
  name: "infernal death knight",
  noun: "knight",
  url: "https://gswiki.play.net/infernal_death_knight",
  picture: "",
  level: 104,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
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
  max_hp: 377,
  speed: nil,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Moonsedge",
      uids: [4577001..4577028, 4577051..4577058, 4577106..4577123, 4577201..4577214, 4577216..4577249]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trio of blue-black diamonds",
        as: (610..645)
      },
      {
        name: "Bite",
        as: 520
      },
      {
        name: "Charge",
        as: 565
      },
      {
        name: "Kick",
        as: 520
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence",
        cs: 452
      },
      {
        name: "Disarm",
        cs: 459
      },
      {
        name: "Massive black ora sword adorned with a trio of blue-black diamonds",
        cs: 456
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave"
      }
    ],
    maneuvers: [
      {
        name: "Spell Cleave"
      },
      {
        name: "Disarm"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "19",
    immunities: [],
    melee: (369..632),
    ranged: (353..463),
    bolt: (353..463),
    udf: (409..715),
    bar_td: 426,
    cle_td: (417..426),
    emp_td: 411,
    pal_td: (365..408),
    ran_td: (503..506),
    sor_td: 425,
    wiz_td: nil,
    mje_td: (342..350),
    mne_td: (342..350),
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
  equipment: [
    "a massive black ora sword adorned with a trio of blue-black diamonds",
    "some darkly blued steel half-plate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Judging from her height, the death knight is a mummified remnant of a powerful warrior, though the flesh has mostly come free from her animated bones. Now, her heavy armor is all that holds her skeletal form together. Her neck ends in a jagged ruin, but over the shattered fragments of her spine hovers a bleached skull that is wreathed in azure flames. Fires burn malevolently in the skull's empty sockets.\n\nAppraisal:\nThe death knight is medium in size and about seven feet high in her current state."
    ],
    arrival: [
      "An infernal death knight just came through a heavy steel portcullis.",
      "An infernal death knight just came through some vaulting grey stone doors."
    ],
    flee: [],
    death: [],
    decay: [
      "Groans and cracks emanate from an infernal death knight's armor as {pronoun} suddenly succumbs to metal fatigue.  Within seconds, {pronoun} skeletal form collapses into blanched powder and blows away.",
      "Maggots and buzzing flies burst from a cadaverous tatterdemalion ghast's flesh as {pronoun} skin peels and crumbles.  The scavenging insects rapidly consume the remains, leaving little but brittle bones."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "Tightening {pronoun} grip on {pronoun} black ora sword, an {pronoun} strikes out at you with all of {pronoun} might!",
        "With effortless ease born of martial training, an infernal death knight swings {weapon} at you!",
        "An infernal death knight throws {pronoun} flaming skull back as {pronoun} unleashes a vile spell!",
        "An infernal death knight leaps from the back of {target} as {target} topples, narrowly avoiding being pinned beneath {target} mount!",
        "An infernal death knight swings a bone-handled black ora-studded maul at you!",
        "An infernal death knight swings a fist at you!",
        "An infernal death knight swings {pronoun} black ora sword at {target} glowbark long bow!",
        "An infernal death knight swings {pronoun} {weapon} at your glowbark long bow!",
        "An infernal death knight swings {pronoun} {weapon} at your black alloy war hammer!",
        "An infernal death knight swings {pronoun} {weapon} at your golvern katana!",
        "An infernal death knight swings {pronoun} {weapon} at your ghezyte long bow!",
        "An infernal death knight swings {pronoun} {weapon} at your smooth glowbark staff!",
        "An infernal death knight swings {pronoun} {weapon} at your gleaming steel baselard!",
        "An infernal death knight swings {pronoun} {weapon} at your golvern lance!",
        "An infernal death knight swings {pronoun} {weapon} at your short sword!",
        "An infernal death knight swings a massive black ora sword adorned with a trio of blue-black diamonds at {target}!",
        "An infernal death knight swings {pronoun} {weapon} at {target} glowbark long bow!",
        "An infernal death knight ignites with spectral cerulean flames as {pronoun} splays a bony hand at you!",
        "An infernal death knight raises {pronoun} skeletal knuckles into a boxer's stance and swings at you!"
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
