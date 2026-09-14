{
  schema_version: 3,
  name: "massive troll king",
  noun: "king",
  url: "https://gswiki.play.net/massive_troll_king",
  picture: "",
  level: 63,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: false,
  max_hp: 400,
  speed: 9,
  height: 11,
  size: "huge",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [388002..388011]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 339
      },
      {
        name: "Claw",
        as: 522
      },
      {
        name: "Bite (enraged)"
      },
      {
        name: "Claw (enraged)"
      },
      {
        name: "Fist",
        as: 502
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Enrage"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (247..249),
    ranged: 249,
    bolt: 237,
    udf: (221..309),
    bar_td: 232,
    cle_td: 250,
    emp_td: 247,
    pal_td: (211..214),
    ran_td: 214,
    sor_td: 262,
    wiz_td: nil,
    mje_td: (207..276),
    mne_td: (207..276),
    mjs_td: 247,
    mns_td: 247,
    mnm_td: 199,
    defensive_spells: [],
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
    skin: "a massive troll king hide",
    other: [
      "trolls blood, Glowing violet essence dust",
      "small troll tooth",
      "large troll tooth"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Massive troll kings are the largest, ugliest, dumbest, and most powerful creatures in the troll family.\n\nThis fierce monster is roughly humanoid, standing nearly 9 feet tall, with long arms ending in razor-sharp claws. Dark green and covered with ugly warts, this hideous being appears unintelligent yet incredibly strong."
    ],
    arrival: [
      "A massive troll king arrives, flexing its massive claws.",
      "A resolute dhu goleras arrives with a loping, uneven gait, her body rocking side-to-side and her head and arms flopping wildly."
    ],
    flee: [],
    death: [
      "The troll king lies still."
    ],
    decay: [
      "A massive troll king decays away into compost.",
      "The thick skin of a minotaur warrior falls in upon itself as his enormous form decays into a fine dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A massive troll king pounds at you with {pronoun} fist!",
        "A massive troll king pounds at {target} with {pronoun} fist!"
      ],
      claw: [
        "A massive troll king claws at you!"
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
