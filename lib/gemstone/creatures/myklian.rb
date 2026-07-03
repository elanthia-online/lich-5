{
  schema_version: 3,
  name: "myklian",
  noun: "",
  url: "https://gswiki.play.net/myklian",
  picture: "",
  level: 40,
  family: "Reptilian",
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
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Broken Lands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 251
      },
      {
        name: "Claw",
        as: (215..310)
      },
      {
        name: "Stomp",
        as: 241
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
    asg: nil,
    immunities: [],
    melee: 163,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: (145..169),
    pal_td: nil,
    ran_td: nil,
    sor_td: (132..237),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 176,
    mjs_td: 202,
    mns_td: (159..161),
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
    skin: "a (color) myklian scale",
    other: nil
  },
  messaging: {
    description: [
      "The myklian is a fearsome beast, some form of large lizard or amphibian that usually travels on four legs, but sometimes stands upright on two legs. It has a short, stubby tail which is triangular in shape and covered with a luminescent, chitinous plate. Hard scales cover the rest of the beast's body, except for the soft underbelly. Bony spikes and knobs guard the beast's joints. The coloration of the myklian species ranges the entire spectrum, red, orange, yellow, green, blue and purple."
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
