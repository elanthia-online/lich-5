{
  schema_version: 3,
  name: "ethereal mage apprentice",
  noun: "apprentice",
  url: "https://gswiki.play.net/ethereal_mage_apprentice",
  picture: "",
  level: 54,
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
  bcs: true,
  max_hp: 240,
  speed: 10,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377002..377008, 377013..377015, 377020..377030, 377320..377328]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hissing stream of acid",
        as: 293
      },
      {
        name: "Large boulder",
        as: 261
      },
      {
        name: "Polished black oak runestaff",
        as: 288
      },
      {
        name: "Roaring ball of fire",
        as: 265
      },
      {
        name: "Stream of fire",
        as: 288
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (218..446),
    ranged: (189..353),
    bolt: (189..353),
    udf: (276..416),
    bar_td: nil,
    cle_td: (217..226),
    emp_td: (224..234),
    pal_td: (205..208),
    ran_td: (187..195),
    sor_td: (243..252),
    wiz_td: nil,
    mje_td: (269..398),
    mne_td: (269..398),
    mjs_td: 282,
    mns_td: 282,
    mnm_td: (176..185),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a polished black oak runestaff",
    "a polished red steel Hammer of Kai",
    "some simple buff tattered leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "inky necrotic core"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Twisted and warped in the service of the Council of Twelve, the apprentice floats several inches over the floor, hunched over, gazing at his surroundings with abnormally large yellow-hued eyes framed by translucent, rotting and pestilent skin. Draped over his broken form are the remnants of a once simple, but finely crafted robe. Cinching the robe at the waist is a thick black belt, adorned with numerous leather pouches once used to hold the supplies desired by his arcane master."
    ],
    arrival: [],
    flee: [
      "An ethereal mage apprentice floats {direction}.",
      "An ethereal mage apprentice drifts {direction}."
    ],
    death: [],
    decay: [],
    search: [
      "An ethereal mage apprentice searches about the room saying, \"We must prevent the krolvin scum from taking the Citadel. Civilization cannot be allowed to be extinguished!\""
    ],
    spell_prep: [
      "An ethereal mage apprentice whispers a magical incantation, bending the elements to {pronoun} whim."
    ],
    attacks: {
      attack: [
        "An ethereal mage apprentice swings {weapon} at you!",
        "An ethereal mage apprentice slowly extends {pronoun} hand toward you!"
      ],
      hurl: [
        "An ethereal mage apprentice hurls {weapon} at you!"
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
