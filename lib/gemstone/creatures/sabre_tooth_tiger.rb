{
  schema_version: 3,
  name: "sabre-tooth tiger",
  noun: "tiger",
  url: "https://gswiki.play.net/sabre-tooth_tiger",
  picture: "",
  level: 53,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 6,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Great Mountain Aenatumgana",
      uids: [4561010..4561020, 4561102..4561140, 4561201..4561208]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (244..313)
      },
      {
        name: "Charge",
        as: (283..315)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Leap"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (173..467),
    ranged: (225..258),
    bolt: (225..258),
    udf: (345..374),
    bar_td: nil,
    cle_td: (187..193),
    emp_td: (186..195),
    pal_td: (159..168),
    ran_td: (159..168),
    sor_td: (197..206),
    wiz_td: nil,
    mje_td: (209..218),
    mne_td: (209..218),
    mjs_td: (186..199),
    mns_td: (186..199),
    mnm_td: (150..165),
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
    skin: "a tiger incisor",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A sabre-tooth tiger charges at you!"
      ],
      bite: [
        "A sabre-tooth tiger tries to bite you!"
      ]
    },
    stand: [
      "A sabre-tooth tiger stands up and roars!"
    ],
    description: [
      "The huge sabre-tooth tiger is obviously a formidable predator, measuring more than 15 feet from the nose to the tip of her tail. Flexing massive shoulders above powerful forelegs, the tiger growls and snarls, exposing the elongated canines that give her her name. The tiger's magnificent striped pelt gradates from a soft tan undertone along the spine to a powder white on belly and legs."
    ],
    arrival: [
      "A sabre-tooth tiger prowls in!",
      "A shining sabre-tooth tiger prowls in!",
      "A sparkling sabre-tooth tiger prowls in!",
      "A shadowy sabre-tooth tiger prowls in!",
      "A shielded sabre-tooth tiger prowls in!"
    ],
    flee: [
      "A sabre-tooth tiger prowls {direction}.",
      "A shielded sabre-tooth tiger prowls {direction}."
    ],
    death: [
      "The sabre-tooth tiger crumples to the ground and dies.",
      "The sabre-tooth tiger lets out a final caterwaul and dies."
    ],
    decay: [
      "A sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A dazzling sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A steadfast sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A shining sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A sparkling sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A tenebrous sabre-tooth tiger decays into a compost of fangs, fur and claws.",
      "A shadowy sabre-tooth tiger decays into a compost of fangs, fur and claws."
    ],
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
