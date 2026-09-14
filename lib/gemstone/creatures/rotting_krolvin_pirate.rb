{
  schema_version: 3,
  name: "rotting krolvin pirate",
  noun: "pirate",
  url: "https://gswiki.play.net/rotting_krolvin_pirate",
  picture: "",
  level: 18,
  family: "Krolvin",
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
  max_hp: 212,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377201..377232]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: 173
      },
      {
        name: "Trident",
        as: 173
      },
      {
        name: "Corroded long-handled gaff",
        as: 155
      },
      {
        name: "Weathered boarding axe",
        as: 153
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Trip"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (46..130),
    ranged: (43..81),
    bolt: (43..81),
    udf: (81..134),
    bar_td: 54,
    cle_td: 54,
    emp_td: 54,
    pal_td: (51..54),
    ran_td: (54..60),
    sor_td: 54,
    wiz_td: nil,
    mje_td: (51..60),
    mne_td: (51..60),
    mjs_td: (51..60),
    mns_td: (51..60),
    mnm_td: 54,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a corroded long-handled gaff",
    "some rotting studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: [
      "warped wooden shield",
      "weathered boarding axe"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Gnarled white hair drapes in locks over the krolvin pirate's face, which is fixed in a constant murderous leer. The pirate's puffy grayish-blue skin is slashed and punctured with what must have been mortal wounds, but the foul creature before you pays the ancient injuries no heed as she seeks to continue her plundering ways well beyond the grave."
    ],
    arrival: [
      "A rotting krolvin pirate swaggers in."
    ],
    flee: [
      "A rotting krolvin pirate swaggers {direction}.",
      "A rotting krolvin pirate limps as he staggers {direction}."
    ],
    death: [
      "The krolvin pirate spits out one last curse and lies still.",
      "The krolvin pirate vainly struggles to rise, then goes still."
    ],
    decay: [
      "The krolvin pirate decays into a pile of compost, releasing a stench of rotting seaweed."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A rotting krolvin pirate swings {weapon} at you!",
        "A rotting krolvin pirate thrusts with a corroded long-handled gaff at you!",
        "A rotting krolvin pirate pounds {pronoun} chest and roars, \"Moradg tezt gno Krol!\""
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
