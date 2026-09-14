{
  schema_version: 3,
  name: "scaly burgee",
  noun: "burgee",
  url: "https://gswiki.play.net/scaly_burgee",
  picture: "",
  level: 29,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 340,
  speed: nil,
  height: 2,
  size: "large",
  areas: [
    {
      name: "Teorainn Dale",
      uids: [13024030..13024047, 13024051..13024064]
    },
    {
      name: "Greymist Woods",
      uids: [3022018..3022034]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 250
      },
      {
        name: "Claw",
        as: (225..247)
      },
      {
        name: "Charge",
        as: 221
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Spit"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (168..270),
    ranged: (127..175),
    bolt: (127..175),
    udf: (168..289),
    bar_td: 87,
    cle_td: (84..93),
    emp_td: (87..95),
    pal_td: (84..93),
    ran_td: (87..93),
    sor_td: (88..97),
    wiz_td: nil,
    mje_td: (95..98),
    mne_td: (95..98),
    mjs_td: (87..98),
    mns_td: (87..98),
    mnm_td: (81..90),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a scaly burgee shell",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dark, beady eyes of the scaly burgee gleam with feral menace beneath two jutting ridges. Flexible diamond-shaped scales cover its carapace and its small, triangular head. Thinly coated around its surprisingly wide mouth is a greyish substance."
    ],
    arrival: [
      "A scaly burgee waddles in and sniffs about."
    ],
    flee: [
      "A scaly burgee grunts and waddles {direction}."
    ],
    death: [],
    decay: [
      "A scaly burgee decays away, leaving behind little more than dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A scaly burgee charges at you!"
      ],
      claw: [
        "A scaly burgee claws at you!"
      ]
    },
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
