{
  schema_version: 3,
  name: "war griffin",
  noun: "",
  url: "https://gswiki.play.net/war_griffin",
  picture: "",
  level: 100,
  family: "Griffin",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Ta'Faendryl",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (435..460)
      },
      {
        name: "Claw",
        as: (445..470)
      },
      {
        name: "Impale",
        as: 436
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Screech"
      },
      {
        name: "Wing buffet"
      },
      {
        name: "Wing swat"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: 343,
    ranged: nil,
    bolt: 347,
    udf: nil,
    bar_td: 390,
    cle_td: (409..418),
    emp_td: (409..415),
    pal_td: 360,
    ran_td: nil,
    sor_td: 439,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: (400..409),
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
    coins: false,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a war griffin talon",
    other: "Alchemy"
  },
  messaging: {
    description: [
      "The war griffin is a magnificent beast, as if designed by the gods to embody fierce and graceful predation. Its front legs, forebody, wings, and head are those of a great eagle, complete with large golden feathers and aquiline beak. The rear half of the creature's body is that of a powerful lion, with short white fur and a long feline tail. Trained by its captors to enhance its fighting prowess, the massive war griffin is poetry in motion, its beautiful ferocity the last sight its foes ever see."
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
