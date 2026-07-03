{
  schema_version: 3,
  name: "flesh golem",
  noun: "",
  url: "https://gswiki.play.net/flesh_golem",
  picture: "",
  level: 50,
  family: "golem",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Corporeal undead",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marsh Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound (double attack)",
        as: 300
      },
      {
        name: "Stomp",
        as: 300
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Noxious Cloud"
      },
      {
        name: "Twin Hammerfists"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 146,
    ranged: nil,
    bolt: 145,
    udf: nil,
    bar_td: 169,
    cle_td: 185,
    emp_td: 183,
    pal_td: 160,
    ran_td: nil,
    sor_td: 194,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 183,
    mjs_td: 183,
    mns_td: 183,
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
    other: nil
  },
  messaging: {
    description: [
      "Overlapping layers of skin are stitched together in a patchwork pattern over a frame of bone to resemble the form of a man. Dark creases in the flesh offer the only indication of features in the golem's face, while the rest of its body is composed of blubbery mass and the occasional portion of some humanoid race, from kobold to krolvin. Two lengthy, thick arms that end in huge swollen fists distract from the great height of the golem."
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
