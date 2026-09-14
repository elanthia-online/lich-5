{
  schema_version: 3,
  name: "aivren",
  noun: "aivren",
  url: "https://gswiki.play.net/aivren",
  picture: "",
  level: 86,
  family: "Aivren",
  type: "Avian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 300,
  speed: 5,
  height: nil,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4568028..4568055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 398
      },
      {
        name: "Claw (attack)",
        as: 378
      },
      {
        name: "Bite",
        as: 403
      },
      {
        name: "Massive beak",
        as: 358
      },
      {
        name: "Razor-sharp claw",
        as: 410
      },
      {
        name: "Swoop",
        as: 410
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Wing Buffet"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (300..400),
    ranged: (263..404),
    bolt: (263..404),
    udf: 473,
    bar_td: 320,
    cle_td: 338,
    emp_td: (332..341),
    pal_td: (289..301),
    ran_td: 301,
    sor_td: 354,
    wiz_td: nil,
    mje_td: (367..373),
    mne_td: (367..373),
    mjs_td: (320..332),
    mns_td: (320..332),
    mnm_td: (271..319),
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
    skin: "an aivren gizzard",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Leathery, ochre wings extending as wide as a giantman is tall, the aivren wheels and swoops with amazing dexterity. The aivren flies low over the landscape, snapping up anything remotely edible in its long, pointed beak or sharp, descending claws. Charcoal grey on the underbelly and a dusky ochre on the back, its speed often surprises its foes, allowing the aivren to strike the death blow before the opponent can react."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An aivren rakes at you with a razor-sharp claw!",
        "An aivren tries to spear you with {pronoun} massive beak!"
      ],
      bite: [
        "An aivren tries to bite you!"
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
