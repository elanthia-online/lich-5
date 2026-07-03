{
  schema_version: 3,
  name: "vaespilon",
  noun: "",
  url: "https://gswiki.play.net/vaespilon",
  picture: "",
  level: 93,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Rift",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Implosion (720)"
      },
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Bravery (211)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (255..400),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 334,
    ran_td: nil,
    sor_td: 421,
    wiz_td: nil,
    mje_td: 434,
    mne_td: 436,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Wall of Force (140)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Barrier (430)"
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
    other: "[[Inky necrotic core]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The vaespilon's features are so terribly deformed by death's ravages, her expression is one of almost comical surprise, until her smile widens into a grin that is a study in terror.  The skin covering the walking corpse is mottled and stretched unevenly over the bones, and the surface ripples and bulges as if putrescence is bubbling underneath.  The vaespilon hisses in glee as she moves, a wave of stench preceding her like an invisible assailant.</pre>"
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
