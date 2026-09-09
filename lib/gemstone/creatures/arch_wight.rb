{
  schema_version: 3,
  name: "arch wight",
  noun: "wight",
  url: "https://gswiki.play.net/arch_wight",
  picture: "",
  level: 20,
  family: "Wight",
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
  max_hp: 170,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Castle Anwyn",
      uids: [4285023..4285023, 4285030..4285030, 4285051..4285057, 4285100..4285103]
    },
    {
      name: "Plains of Bone",
      uids: [14011023..14011041]
    },
    {
      name: "The Graveyard",
      uids: [18101..18110, 18200..18209, 2162113..2162122]
    },
    {
      name: "Abbey",
      uids: [4132101..4132118]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: (144..156)
      },
      {
        name: "Claw",
        as: 136
      },
      {
        name: "Twohanded sword",
        as: 150
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Mind Jolt (706)",
        cs: 123
      },
      {
        name: "Empathy (1108)"
      },
      {
        name: "Scimitar",
        cs: 129
      },
      {
        name: "Twohanded sword",
        cs: 117
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Gas cloud"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      },
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: (59..165),
    ranged: (38..70),
    bolt: (38..70),
    udf: (73..163),
    bar_td: 66,
    cle_td: (57..66),
    emp_td: (60..68),
    pal_td: (57..66),
    ran_td: (54..63),
    sor_td: 60,
    wiz_td: 60,
    mje_td: 60,
    mne_td: 60,
    mjs_td: (57..66),
    mns_td: (57..66),
    mnm_td: (57..60),
    defensive_spells: [
      "Spirit Warding II (107)",
      "Spell Shield (219)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened scimitar",
    "a corroded steel scimitar",
    "a scimitar",
    "a war hammer",
    "some cuirbouilli leather",
    "some tattered gilt-edged silk robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a wight skin",
    other: "glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The arch wight moves along ponderously, its gaunt humanoid frame often bent nearly double as it walks through the corridors of the deceased. Massive upper arms contrast with a thin torso and narrow hips. Its liquid golden eyes seem to be filled with tiny red sparks, and the lack of flesh on its face causes the arch wight to sport a horrific toothy grin. Very proficient in the ways of magic, the arch wight feasts upon the flesh of the deceased, but often cooks the living to death before indulging in its grisly meal."
    ],
    arrival: [
      "An arch wight just arrived."
    ],
    flee: [
      "An arch wight runs {direction}.",
      "An arch wight limps {direction}."
    ],
    death: [
      "The arch wight falls to the ground motionless.",
      "The arch wight screams evilly one last time and goes still."
    ],
    decay: [
      "An arch wight crumbles to dust."
    ],
    search: [],
    spell_prep: [
      "An arch wight chants an evil incantation.",
      "An arch wight gestures at {target}!",
      "An arch wight's eyes flare with delight as {pronoun} eyes a blackened twohanded sword."
    ],
    attacks: {
      attack: [
        "An arch wight swings {weapon} at you!"
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
