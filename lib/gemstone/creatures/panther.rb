{
  schema_version: 3,
  name: "panther",
  noun: "panther",
  url: "https://gswiki.play.net/panther",
  picture: "",
  level: 15,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 140,
  speed: 12,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Plains of Vornavis",
      uids: [4212301..4212324]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (150..174)
      },
      {
        name: "Claw",
        as: (134..174)
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
    asg: "6N",
    immunities: [],
    melee: (92..151),
    ranged: (79..97),
    bolt: (79..97),
    udf: (112..168),
    bar_td: (33..51),
    cle_td: (39..48),
    emp_td: (45..53),
    pal_td: (36..45),
    ran_td: (42..51),
    sor_td: (42..51),
    wiz_td: nil,
    mje_td: (39..48),
    mne_td: (39..48),
    mjs_td: (42..54),
    mns_td: (42..54),
    mnm_td: (42..51),
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
    skin: "a panther pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The panther is a large, black cat with a slender body and long tail. Often approaching and striking silently, he affords his prey little warning. Powerful jaws bite and sharp claws rend as the panther attempts to secure enough food for another day. Even when satiated, though, the panther enjoys killing just for the pleasure of it."
    ],
    arrival: [
      "A panther scampers in!",
      "A panther scampers in, mewling in pain!",
      "A panther pounces to the ground in front of you!"
    ],
    flee: [
      "A panther scampers {direction}.",
      "A panther scampers {direction}, mewling in pain."
    ],
    death: [
      "The panther lets out a final caterwaul and dies.",
      "The panther crumples to the ground and dies."
    ],
    decay: [
      "A panther decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A panther claws at you!"
      ],
      bite: [
        "A panther tries to bite you!"
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
