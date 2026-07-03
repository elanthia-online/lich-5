{
  schema_version: 3,
  name: "spectral monk",
  noun: "",
  url: "https://gswiki.play.net/spectral_monk",
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
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 205,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Monastery",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 227
      },
      {
        name: "Scythe",
        as: 227
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Silence (210)",
        cs: 136
      },
      {
        name: "Frenzy (216)",
        cs: 136
      },
      {
        name: "Blind (311)",
        cs: 142
      },
      {
        name: "Mind Jolt (706)",
        cs: 146
      }
    ],
    offensive_spells: [
      {
        name: "Bravery (211)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (225..235),
    ranged: nil,
    bolt: (100..132),
    udf: nil,
    bar_td: nil,
    cle_td: (76..101),
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 107,
    wiz_td: nil,
    mje_td: 98,
    mne_td: 98,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Shield (202)",
      "Prismatic Guard (905)",
      "Prayer of Protection (303)"
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
      "<pre{{log2|margin-right=26em}}>A tattered black cowl obscures the spectral monk's face.  Given the burning green eyes and foul stench he exudes, perhaps that is for the best.  Tattered rags cloak his shimmering pellucid form.  Its ghostly body flickers in and out of existance, as if only his desire to destroy keeps him bound to this plane.</pre>"
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
