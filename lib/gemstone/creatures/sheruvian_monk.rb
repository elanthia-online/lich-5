{
  schema_version: 3,
  name: "Sheruvian monk",
  noun: "monk",
  url: "https://gswiki.play.net/sheruvian_monk",
  picture: "",
  level: 41,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 5,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Broken Lands",
      uids: [487020..487025, 487030..487032, 487034..487041, 487043..487043, 487058..487075]
    },
    {
      name: "unmapped",
      uids: [487042..487042]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Jeddart-axe",
        as: (239..314)
      },
      {
        name: "Lunge",
        as: (269..299)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Healing"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (255..340),
    ranged: (220..305),
    bolt: (220..305),
    udf: 276,
    bar_td: 143,
    cle_td: 156,
    emp_td: 231,
    pal_td: (130..133),
    ran_td: 133,
    sor_td: (164..231),
    wiz_td: nil,
    mje_td: 172,
    mne_td: 172,
    mjs_td: 231,
    mns_td: 231,
    mnm_td: 123,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a black steel jeddart-axe",
    "some black velvet robes"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "It is hard to tell if the Sheruvian monk is human, or some foul spawn of inhuman parents. The head of the warrior-monk has been shaved smooth and is covered in dark, mystic runes tattooed on its scalp. A heavy brow hangs low over its cold, calculating eyes."
    ],
    arrival: [
      "A Sheruvian monk just arrived.",
      "A Sheruvian monk just came through a sculpted black vaalin arch.",
      "A Sheruvian monk just came through a polished engraved maoral door.",
      "A Sheruvian monk just came through an iron-bound heavy modwir door.",
      "A Sheruvian monk just came through some polished maoral double doors.",
      "A Sheruvian monk just came through a curtained polished ivory arch.",
      "A Sheruvian monk just came through an ornate black marble arch."
    ],
    flee: [],
    death: [
      "The Sheruvian monk screams emotionlessly one last time and lies still.",
      "The Sheruvian monk falls to the ground and lies still."
    ],
    decay: [],
    search: [
      "The Sheruvian monk searches around looking for something.",
      "The Sheruvian monk glances around, sure {pronoun} has missed something."
    ],
    spell_prep: [
      "A Sheruvian monk hisses, \"Sheru will arise victorious this day!\""
    ],
    attacks: {
      attack: [
        "A Sheruvian monk lunges at you!  As you shift to block the blow, the monk reverses {pronoun} swing, coming in low to your left side!",
        "A Sheruvian monk snarls as it launches itself at you!",
        "A Sheruvian monk swings {weapon} at you!",
        "A Sheruvian monk lunges at you!  As you shift to block the blow, the Sheruvian monk reverses {pronoun} swing, coming in low to your left side!",
        "A Sheruvian monk leaps to {pronoun} feet, {pronoun} eyes darting around looking for trouble."
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
