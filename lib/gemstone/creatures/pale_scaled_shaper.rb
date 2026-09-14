{
  schema_version: 3,
  name: "pale scaled shaper",
  noun: "shaper",
  url: "https://gswiki.play.net/pale_scaled_shaper",
  picture: "",
  level: 102,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 8,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Shadow of the Sanctum",
      uids: [4216001..4216049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Major Fire"
      },
      {
        name: "Long acacia runestaff",
        as: 517
      }
    ],
    warding_spells: [
      {
        name: "Disintegrate",
        cs: 353
      },
      {
        name: "Cloak of Shadows",
        cs: 431
      },
      {
        name: "Long acacia runestaff",
        cs: 445
      }
    ],
    offensive_spells: [
      {
        name: "Gas cloud"
      },
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Spiritual Abolition"
      },
      {
        name: "Condemn"
      }
    ],
    maneuvers: [
      {
        name: "Skeletal Finger"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: 555,
    ranged: (429..630),
    bolt: (431..630),
    udf: (698..699),
    bar_td: nil,
    cle_td: 441,
    emp_td: (432..442),
    pal_td: 349,
    ran_td: 368,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I",
      "Spirit Warding II",
      "Lesser Shroud",
      "Cloak of Shadows",
      "Spirit Shield",
      "Bravery",
      "Thurfel's Ward"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Summons sidewinder cobras",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a long acacia runestaff capped with a carved ivory serpent",
    "some pallid robes"
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
      "A pale scaled shaper is far taller than a woman ought to be, with a stretched appearance like that of a doll tugged by battling children. That is, if she is even female: the pale robes that she wears, with their faint appliqued patterns of winking copper scales, betray only the most suggestive promise of a feminine form beneath. There is something upsettingly inhuman about the shaper's face, which has the shape and proportions of a human's, but eyes that glow like green embers and a dusting of ridged scales on its cheeks and brow."
    ],
    arrival: [
      "A pale scaled shaper just arrived.",
      "A pale scaled shaper just came through a polished acacia archway.",
      "A pale scaled shaper just came through a pair of high bronze double doors.",
      "A pale scaled shaper just came through a towering black ora gate."
    ],
    flee: [
      "A pale scaled shaper just went through a polished acacia archway.",
      "A pale scaled shaper just went into a huge sandstone spire."
    ],
    death: [
      "A spectral howl echoes through the air, resonant with pain and anguish, and then fades into heavy silence.  The scaly veneer covering a pale scaled shaper shimmers briefly before melting into {pronoun} skin."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A pale scaled shaper whispers an inhuman entreaty, and the shadows grow frenized and green-tinged around {pronoun}.",
      "A pale scaled shaper hisses out a sibilant incantation in an unknown language.",
      "A pale scaled shaper gestures at you, sending snatching tendrils of green-black energy crackling in your direction!"
    ],
    attacks: {
      attack: [
        "A pale scaled shaper smirks, flicking a skeletal finger toward you!",
        "With serpentine speed, a pale scaled shaper swings {weapon} at you!",
        "A pale scaled shaper flings a roiling sphere of emerald flame at you!",
        "A pale scaled shaper throws {pronoun} acacia runestaff into the air, charging {pronoun} with an eruption of virescent energy. The carved serpent entwining it twitches to life with a hiss, uncoiling from the runestaff and dropping to the ground, quickening into {target}! The shaper's runestaff floats back into {pronoun} waiting hand."
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
