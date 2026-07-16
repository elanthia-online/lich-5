{
  schema_version: 3,
  name: "dark shambler",
  noun: "",
  url: "https://gswiki.play.net/dark_shambler",
  picture: "",
  level: 17,
  family: "Humanoid",
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
  max_hp: 200,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Plains of Bone",
      rooms: []
    },
    {
      name: "Sentoph",
      rooms: []
    },
    {
      name: "Temple of Hope",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword",
        as: 175
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
    asg: "10",
    immunities: [],
    melee: (104..112),
    ranged: (97..114),
    bolt: 94,
    udf: 121,
    bar_td: 51,
    cle_td: 51,
    emp_td: 51,
    pal_td: 51,
    ran_td: 51,
    sor_td: 51,
    wiz_td: 51,
    mje_td: 51,
    mne_td: 51,
    mjs_td: 51,
    mns_td: 51,
    mnm_td: 51,
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
    skin: "a glistening black eye",
    other: nil
  },
  messaging: {
    description: [
      "Very little of the dark shambler is not thickly muscled. This squat humanoid lumbers through the countryside, surveying the world through glistening black eyes. Were it not for the eyes, the dark shambler could almost be taken for a shadow from a distance, for its skin is also entirely black. The eyes glisten eerily, though, while the rest of the dark shambler is a flat shade of charcoal that appears to absorb the light more than reflect it."
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
