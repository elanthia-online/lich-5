{
  schema_version: 3,
  name: "enormous mosquito",
  noun: "mosquito",
  url: "https://gswiki.play.net/enormous_mosquito",
  picture: "",
  level: 22,
  family: "",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 214,
  speed: 10,
  height: nil,
  size: "",
  areas: [
    {
      name: "Monsoon Jungle",
      uids: [3218001..3218046, 3218049..3218054]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dive",
        as: 216
      },
      {
        name: "(quarantine-recovered)",
        as: 216
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Blood drain"
      },
      {
        name: "Dive"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (108..140),
    ranged: (103..112),
    bolt: (103..112),
    udf: (262..300),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (63..66),
    sor_td: 70,
    wiz_td: nil,
    mje_td: 72,
    mne_td: 72,
    mjs_td: nil,
    mns_td: 68,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blinded left eye",
    "a possible mild concussion"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "diaphanous mosquito wing",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Supported in the back by a pair of middle and hind legs, the mosquito lightly rests its weight upon multi-jointed forelegs. Feather-like antennae twitch back and forth from their perch around its palps, while its long proboscis exudes a needle-sharp quality that is clearly visible from any angle. Compound eyes, black and seemingly lifeless, take over most of its head. Shorter than its abdominal segments, its translucent, cross-veined wings are joined to its body at the hip."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [
      "Growing brittle, the enormous mosquito's body suddenly caves in and turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An enormous mosquito suddenly dives at you!"
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
