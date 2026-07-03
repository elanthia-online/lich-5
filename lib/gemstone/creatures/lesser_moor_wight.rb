{
  schema_version: 3,
  name: "lesser moor wight",
  noun: "",
  url: "https://gswiki.play.net/lesser_moor_wight",
  picture: "",
  level: 37,
  family: "Wight",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Black Moor",
      rooms: []
    },
    {
      name: "Miasmal Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 250
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Gas cloud"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 133,
    udf: nil,
    bar_td: (110..115),
    cle_td: (100..119),
    emp_td: 110,
    pal_td: nil,
    ran_td: nil,
    sor_td: 119,
    wiz_td: nil,
    mje_td: (119..134),
    mne_td: 130,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Thurfel's Ward (503)"
    ],
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
    skin: "wight skull",
    other: nil
  },
  messaging: {
    description: [
      "Once beautiful beyond comprehension, the moor wight before you is now as disgusting as it was once charming. The wight has a slender, decaying body hidden by tattered and fading robes. Plainly written across the moor wight's face is an expression of eternal anguish and pain, silently speaking of the horrofic events which unfolded during its life to bring it to this sad state."
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
