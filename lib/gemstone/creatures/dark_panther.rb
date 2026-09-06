{
  schema_version: 3,
  name: "dark panther",
  noun: "panther",
  url: "https://gswiki.play.net/dark_panther",
  picture: "",
  level: 22,
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
  max_hp: 196,
  speed: 10,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Karazja Jungle",
      uids: [5006004..5006009, 5006040..5006040]
    },
    {
      name: "Vipershroud",
      uids: [2190001..2190025, 2190027..2190034]
    },
    {
      name: "unmapped",
      uids: [5006010..5006039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (178..198)
      },
      {
        name: "Bite",
        as: 198
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
    asg: "8N",
    immunities: [],
    melee: (122..181),
    ranged: (112..123),
    bolt: (112..123),
    udf: (187..204),
    bar_td: nil,
    cle_td: (63..72),
    emp_td: (68..76),
    pal_td: (60..66),
    ran_td: (60..66),
    sor_td: (70..76),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 72,
    mjs_td: 99,
    mns_td: 99,
    mnm_td: 66,
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "dark panther pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dark panther is a large, black cat with a slender body and long tail. The dark panther often approaches and strikes silently, affording her prey little warning. Powerful jaws bite and sharp claws rend as the dark panther attempts to secure enough food for another day. Even when satiated, though, the dark panther enjoys killing just for the pleasure of it."
    ],
    arrival: [
      "A dark panther scampers in!",
      "A dark panther scampers in, mewling in pain!",
      "A dark panther pounces to the ground in front of you!"
    ],
    flee: [
      "A dark panther scampers {direction}.",
      "A dark panther scampers {direction}, mewling in pain."
    ],
    death: [
      "The dark panther lets out a final caterwaul and dies.",
      "The dark panther crumples to the ground and dies."
    ],
    decay: [
      "A dark panther decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A dark panther claws at you!"
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
