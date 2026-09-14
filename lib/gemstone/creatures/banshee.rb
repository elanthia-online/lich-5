{
  schema_version: 3,
  name: "banshee",
  noun: "banshee",
  url: "https://gswiki.play.net/banshee",
  picture: "",
  level: 50,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 300,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [42001..42016, 44001..44006, 44033..44036, 44046..44051]
    },
    {
      name: "Fhorian Village",
      uids: [3030256..3030268]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 275
      },
      {
        name: "Claw",
        as: (265..275)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Scream",
        cs: 230
      },
      {
        name: "Claw",
        cs: 230
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (199..415),
    ranged: (210..384),
    bolt: (210..384),
    udf: (325..417),
    bar_td: 179,
    cle_td: 279,
    emp_td: (193..202),
    pal_td: (166..175),
    ran_td: (157..166),
    sor_td: (204..213),
    wiz_td: nil,
    mje_td: (214..215),
    mne_td: (214..215),
    mjs_td: (193..202),
    mns_td: (193..202),
    mnm_td: (228..234),
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
    skin: nil,
    other: [
      "Inky necrotic core",
      "glowing violet mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Speculated to have been a female wizard or sorcerer, this horrible creature has been bound to life after death by some horrible magic. Her rotting teeth, decaying flesh, and tattered robes leave little evidence left of her original appearance. Fading in and out of view, at times you can even see straight through her to the other side!\n\nAppraisal: The banshee is medium in size and about five feet high in her current state."
    ],
    arrival: [],
    flee: [
      "A banshee floats {direction}."
    ],
    death: [],
    decay: [
      "A banshee dissolves away.",
      "The banshee slumps to the floor, exhales a sigh of relief, and begins to quickly decay away.",
      "The banshee exhales a sigh of relief and begins to quickly decay away."
    ],
    search: [],
    spell_prep: [
      "The banshee whispers, \"Soon, soon, soon, soon...\" and then shrieks with laughter, an ear-piercing sound of such abysmal power that {pronoun} rattles straight through your bones."
    ],
    attacks: {
      claw: [
        "A banshee claws at you!"
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
