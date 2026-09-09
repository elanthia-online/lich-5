{
  schema_version: 3,
  name: "werebear",
  noun: "werebear",
  url: "https://gswiki.play.net/werebear",
  picture: "",
  level: 10,
  family: "Bear",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: nil,
  max_hp: 150,
  speed: 9,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [16036..16041]
    },
    {
      name: "Cairnfang",
      uids: [630015..630029]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 130
      },
      {
        name: "Claw",
        as: 130
      },
      {
        name: "Charge (attack)",
        as: 140
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
    asg: "8N",
    immunities: [],
    melee: (57..87),
    ranged: (55..85),
    bolt: (55..85),
    udf: 85,
    bar_td: nil,
    cle_td: 30,
    emp_td: (30..39),
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 30,
    mjs_td: (30..39),
    mns_td: (30..39),
    mnm_td: 30,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a werebear paw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Smaller than a normal bear, the werebear still presents a menacing aspect. Eyes that glitter with a shred of their former humanity glare out at the world with undisguised rage and hate. Thick dark fur combined with a tough hide gives the beast a solid defense, and huge paws tipped with razor sharp claws give pause to even the well-armed adventurer."
    ],
    arrival: [
      "A werebear lumbers in, uttering a weird half-human cry!",
      "A werebear just arrived.",
      "A werebear lumbers out of the underbrush, uttering a weird, half-human cry!"
    ],
    flee: [
      "A werebear lumbers {direction} of the underbrush, uttering a weird, half-human cry!",
      "A werebear lumbers {direction}, uttering a weird half-human cry!"
    ],
    death: [
      "A werebear growls one last time, and crumples to the ground in a heap."
    ],
    decay: [
      "A werebear turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A werebear tries to bite you!"
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
