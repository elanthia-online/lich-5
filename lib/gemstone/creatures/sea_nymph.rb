{
  schema_version: 3,
  name: "sea nymph",
  noun: "",
  url: "https://gswiki.play.net/sea_nymph",
  picture: "",
  level: 2,
  family: "Fey",
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
  max_hp: 44,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
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
        name: "Dagger",
        as: 50
      },
      {
        name: "Handaxe",
        as: 50
      },
      {
        name: "Spear",
        as: 50
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 10
      },
      {
        name: "Vibration Chant (1002)",
        cs: 2
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (10..56),
    ranged: 7,
    bolt: 7,
    udf: 52,
    bar_td: 6,
    cle_td: nil,
    emp_td: 6,
    pal_td: nil,
    ran_td: nil,
    sor_td: 6,
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
    skin: nil,
    other: "pristine nymph's hair"
  },
  messaging: {
    description: [
      "Never found far from the life-giving sea, the sea nymph slips onto dry land to waylay unwary adventurers. Depending mostly on her seductive song, she charms her prey into submission, then strikes quickly and deeply with her dagger. From a distance she is often mistaken for a slim sylvan lady. The flowing robe she wears conceals the webbed appendages that give her speed in the ocean."
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
