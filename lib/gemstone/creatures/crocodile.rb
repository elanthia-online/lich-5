{
  schema_version: 3,
  name: "crocodile",
  noun: "",
  url: "https://gswiki.play.net/crocodile",
  picture: "",
  level: 9,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 90,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marshtown",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    },
    {
      name: "Thurfel's Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 137
      },
      {
        name: "Bite",
        as: 127
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Disease (on hit)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (51..80),
    ranged: 45,
    bolt: 40,
    udf: nil,
    bar_td: 33,
    cle_td: nil,
    emp_td: "-11-27",
    pal_td: nil,
    ran_td: nil,
    sor_td: 27,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 27,
    mjs_td: 27,
    mns_td: 27,
    mnm_td: 27,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a crocodile snout",
    other: nil
  },
  messaging: {
    description: [
      "A large scaled lizard, with a wide gaping mouth full of sharp teeth, it has short powerful legs barely long enough to lift the beast off the ground. The crocodile also has a long powerful tail that looks rather dangerous."
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
