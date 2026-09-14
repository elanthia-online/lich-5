{
  schema_version: 3,
  name: "enormous rift crawler",
  noun: "crawler",
  url: "https://gswiki.play.net/enormous_rift_crawler",
  picture: "",
  level: 103,
  family: "Worm",
  type: "Worm",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: 6,
  height: 4,
  size: "huge",
  areas: [
    {
      name: "The Rift",
      uids: [4569001..4569023]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (449..461)
      },
      {
        name: "Charge (attack)",
        as: 447
      },
      {
        name: "Charge",
        as: (459..475)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Burrow"
      },
      {
        name: "Tail slam"
      },
      {
        name: "Tail Swipe"
      },
      {
        name: "Shield Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 483,
    ranged: (321..485),
    bolt: (321..485),
    udf: (434..536),
    bar_td: (388..397),
    cle_td: (422..425),
    emp_td: 423,
    pal_td: (360..363),
    ran_td: 366,
    sor_td: (420..429),
    wiz_td: nil,
    mje_td: (451..460),
    mne_td: (442..460),
    mjs_td: nil,
    mns_td: 406,
    mnm_td: nil,
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
    skin: "a jagged rift crawler tooth",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This creature's monstrous form has the appearance of liquid, distorted glass overlying a fog-swamped night. Its outer flesh is translucent and glossy, run through with thready veins of black and purple. Beneath, the creature seems to have a secondary skin of darkest grey. Not scaled, but segmented, the body within its vitreous shell undulates in a way only smoke can. It roils and shifts as though it were an insubstantial core within a confining barrier. Its maw is a gaping round of ring upon ring of jagged, obsidian-like teeth."
    ],
    arrival: [
      "The enormous rift crawler lurches through the air before finally landing with a solid thud."
    ],
    flee: [],
    death: [
      "As the rift crawler dies, the beast's massive body curls in on itself, convulses once, and stills."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "An enormous rift crawler shakes off the stun."
    ],
    attacks: {
      attack: [
        "An enormous rift crawler charges at you!"
      ],
      bite: [
        "An enormous rift crawler tries to bite you!"
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
