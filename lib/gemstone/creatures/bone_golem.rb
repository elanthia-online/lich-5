{
  schema_version: 3,
  name: "bone golem",
  noun: "",
  url: "https://gswiki.play.net/bone_golem",
  picture: "",
  level: 8,
  family: "Golem",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 90,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Plains of Bone",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 97
      },
      {
        name: "Pound",
        as: 107
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail sweep"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 12,
    ranged: nil,
    bolt: 2,
    udf: nil,
    bar_td: (24..27),
    cle_td: 24,
    emp_td: 24,
    pal_td: 24,
    ran_td: 24,
    sor_td: 24,
    wiz_td: 24,
    mje_td: 24,
    mne_td: 24,
    mjs_td: 24,
    mns_td: 24,
    mnm_td: 24,
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
    skin: "a golem bone",
    other: nil
  },
  messaging: {
    description: [
      "Dried bones send sickening clacking sounds throughout the area at the barest movement of a bone golem. Its large skull capped with twin horns formed of sharply spiraled bone begins a long spine ending in a sharp tail that whips back and forth in a vicious swipe. Even longer than the snout of the bone golem are its sickly jointed claws which have been filed at the ends into terrifying weapons. Contrary to the empty feeling of its bones, it moves with the blocky movement of an enormous, fleshed creature."
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
