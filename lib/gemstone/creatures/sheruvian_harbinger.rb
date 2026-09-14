{
  schema_version: 3,
  name: "Sheruvian harbinger",
  noun: "harbinger",
  url: "https://gswiki.play.net/sheruvian_harbinger",
  picture: "",
  level: 63,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 240,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [388012..388019, 388030..388035]
    },
    {
      name: "The Broken Lands",
      uids: [487019..487041, 487043..487052, 487054..487054, 487056..487075]
    },
    {
      name: "unmapped",
      uids: [487042..487042, 487053..487053, 487055..487055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (324..404)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 284
      },
      {
        name: "Frenzy (216)",
        cs: 284
      },
      {
        name: "Mind Jolt (706)",
        cs: 291
      },
      {
        name: "Silence (210)",
        cs: 284
      },
      {
        name: "Black steel broadsword",
        cs: 284
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Pale Arm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (189..308),
    ranged: (206..276),
    bolt: (206..276),
    udf: (403..460),
    bar_td: 210,
    cle_td: (222..232),
    emp_td: (219..229),
    pal_td: (186..196),
    ran_td: 186,
    sor_td: (236..244),
    wiz_td: nil,
    mje_td: (248..254),
    mne_td: (248..254),
    mjs_td: (214..229),
    mns_td: (214..229),
    mnm_td: (206..211),
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a black metal breastplate",
    "a black steel broadsword",
    "a reinforced shield",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Sheruvian harbinger is a handsome woman with hypnotic eyes and fair skin. Her demeanor appears emotionless, but you can see some sort of evil fire burning within those dark pupils. A sleek, black breastplate covers most of her torso, and you can see it is made of fine quality. The mere look of the harbinger reminds most people of the tales of the Harbinger of Chaos, spawned forth to do great evil."
    ],
    arrival: [
      "A Sheruvian harbinger just arrived, limping badly.",
      "A Sheruvian harbinger just arrived."
    ],
    flee: [],
    death: [
      "The Sheruvian harbinger collapses on the ground and lies still.",
      "The Sheruvian harbinger releases a horrible wail then lies still."
    ],
    decay: [],
    search: [
      "A Sheruvian harbinger glances around, {pronoun} cold eyes examining the surroundings."
    ],
    spell_prep: [
      "A Sheruvian harbinger hisses an evil incantation."
    ],
    attacks: {
      attack: [
        "A Sheruvian harbinger swings {weapon} at you!",
        "A Sheruvian harbinger raises a pale arm at you!"
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
