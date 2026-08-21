{
  schema_version: 3,
  name: "ethereal mage apprentice",
  noun: "",
  url: "https://gswiki.play.net/ethereal_mage_apprentice",
  picture: "",
  level: 54,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  spawns: [
    { zone: 377, count: 2, uid_ranges: [[377002, 377008], [377013, 377015], [377020, 377030], [377320, 377328]] }
  ],
  attack_attributes: {
    physical_attacks: [],
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
    melee: (255..446),
    ranged: nil,
    bolt: nil,
    udf: 416,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 278,
    mne_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet essence dust"
  },
  messaging: {
    description: [
      "Twisted and warped in the service of the Council of Twelve, the apprentice floats several inches over the floor, hunched over, gazing at his surroundings with abnormally large yellow-hued eyes framed by translucent, rotting and pestilent skin. Draped over his broken form are the remnants of a once simple, but finely crafted robe. Cinching the robe at the waist is a thick black belt, adorned with numerous leather pouches once used to hold the supplies desired by his arcane master."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
