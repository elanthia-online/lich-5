{
  schema_version: 3,
  name: "tomb troll necromancer",
  noun: "",
  url: "https://gswiki.play.net/tomb_troll_necromancer",
  picture: "",
  level: 54,
  family: "Troll",
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
        name: "Runestaff",
        as: 283
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Curse (715)",
        cs: 266
      },
      {
        name: "Limb Disruption (708)",
        cs: 266
      },
      {
        name: "Pain (711)",
        cs: 266
      },
      {
        name: "Blood Burst (701)",
        cs: 266
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Animate Dead (730)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 203,
    udf: nil,
    bar_td: (212..242),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 265,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense II (406)",
      "Fasthr's Reward (115)",
      "Mass Elemental Defense (419)"
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
    skin: "troll eyeball",
    other: nil
  },
  messaging: {
    description: [
      "Similar in appearance to the common tomb troll, the pale skinned necromancer shares the same patches of lanky yellow hair that sporadically cover his squat form. His oversize eyes are filled with a greater intelligence than his cousins', granting him comprehension of the darker arts of necromancy, and making the troll a terror with the magics in the realm of death. Around his wide, disgusting and oily waist, the necromancer wears a string of pouches intermingled with rotting digits of dead kinsmen."
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
