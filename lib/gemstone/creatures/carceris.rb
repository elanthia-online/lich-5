{
  schema_version: 3,
  name: "carceris",
  noun: "",
  url: "https://gswiki.play.net/carceris",
  picture: "",
  level: 25,
  family: "Humanoid",
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
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Anwyn",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 160
      },
      {
        name: "Major Fire (908)",
        as: 160
      },
      {
        name: "Major Shock (910)",
        as: 160
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Earthen Fury (917)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: 243,
    ranged: nil,
    bolt: (140..210),
    udf: nil,
    bar_td: 86,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 96,
    wiz_td: nil,
    mje_td: (96..101),
    mne_td: (96..101),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Prismatic Guard (905)",
      "Mass Blur (911)"
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The carceris makes a peculiar rustling sound as she moves, reminiscent of dried up parchment. The carceris's ragged robes lift and swirl about her like animated tendrils, and bare bones protrude from similar tatters of skin hanging from her hands and hollow cheeks.  The specter bares yellowed teeth, the roots discolored a deep brown where they are anchored in the visible jawbones.  As she circles, constantly whispering a litany of magic, gooey pools of darkness which were once the horror's eyes weep rivulets of stain down the remnants of her face.</pre>"
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
