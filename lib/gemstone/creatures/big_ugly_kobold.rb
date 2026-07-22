{
  schema_version: 3,
  name: "big ugly kobold",
  noun: "",
  url: "https://gswiki.play.net/big_ugly_kobold",
  picture: "",
  level: 2,
  family: "Kobold",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 50,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Kobold Village",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: (36..62)
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
    asg: "1N",
    immunities: [],
    melee: (23..86),
    ranged: nil,
    bolt: 23,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 6,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
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
    skin: "a kobold skin",
    other: nil
  },
  messaging: {
    description: [
      "This big ugly kobold is large for a kobold and ugly, even by kobold beauty standards. Smaller than a dwarf and even many halflings, she has ruddy skin and a hairless pate topped with small horns. Long-limbed for her size, the big ugly kobold eschews any display of brute strength and relies on what agility she pretends to have. The big ugly kobold stares back at you with beady little black eyes, sizing you up as a foe."
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
