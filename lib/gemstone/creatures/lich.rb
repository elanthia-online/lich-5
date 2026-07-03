{
  schema_version: 3,
  name: "lich",
  noun: "",
  url: "https://gswiki.play.net/lich",
  picture: "",
  level: 110,
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
  max_hp: nil,
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
    physical_attacks: [
      {
        name: "Runestaff",
        as: 466
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 422
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 500
      },
      {
        name: "Dark Catalyst (719)",
        cs: (477..489)
      }
    ],
    offensive_spells: [
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Tremors (909)"
      },
      {
        name: "Elemental Disjunction (530)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 661,
    ranged: nil,
    bolt: 550,
    udf: nil,
    bar_td: 439,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (376..391),
    sor_td: 493,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "{{Otheruses4|the creature found in the Rift|the scripting engine|Lich (software)}}\nA Lich can be found in the Scatter in the Rift. This is a highly intelligent spell caster who went to great lengths to gain power and longevity, at the cost of his soul.\n\nLiches can spawn as frostborne or infernal, depending on the temperature of the Scatter at the time."
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
