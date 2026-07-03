{
  schema_version: 3,
  name: "mongrel wolfhound",
  noun: "",
  url: "https://gswiki.play.net/mongrel_wolfhound",
  picture: "",
  level: 16,
  family: "Canine",
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
  max_hp: 150,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Orcswold",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 150
      },
      {
        name: "Charge",
        as: 150
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
    asg: "8N",
    immunities: [],
    melee: (102..150),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (42..48),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 51,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a yellowed canine",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The large canine is obviously closely related to her domestic cousins, but her vicious growl and the feral gleam in her intelligent eyes speak of her far wilder nature.  Ticks and burs speckle her matted, dusty fur, and her wolflike tail sweeps from side to side as she prepares to spring on her intended prey.</pre>"
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
