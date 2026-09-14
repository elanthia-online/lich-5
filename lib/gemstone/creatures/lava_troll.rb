{
  schema_version: 3,
  name: "lava troll",
  noun: "troll",
  url: "https://gswiki.play.net/lava_troll",
  picture: "",
  level: 34,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 4,
  height: 11,
  size: "huge",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023001..3023017]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Maul",
        as: 215
      },
      {
        name: "Warsword",
        as: 215
      },
      {
        name: "Leather-wound ruddy steel sledgehammer",
        as: 215
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (102..260),
    ranged: (98..173),
    bolt: (98..173),
    udf: (156..292),
    bar_td: (105..111),
    cle_td: (110..119),
    emp_td: (111..120),
    pal_td: (102..111),
    ran_td: (102..111),
    sor_td: (123..132),
    wiz_td: nil,
    mje_td: 129,
    mne_td: 129,
    mjs_td: (117..126),
    mns_td: (117..126),
    mnm_td: (102..111),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a leather-wound ruddy steel sledgehammer"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll eye",
    other: [
      "essence of fire",
      "small troll tooth",
      "glimmering blue essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Easily twice as large as the largest giantman, this brutish creature glares with coal black eyes. The lava troll has reddened, blistered skin and soot-black hair. Steam pours from her ears when she bares her blackened fangs."
    ],
    arrival: [],
    flee: [
      "A lava troll crawls {direction}."
    ],
    death: [],
    decay: [
      "A lava troll burns down to a husk, that crumbles to ash.",
      "A lava troll melts into a flow of molten lava that rises up and reforms into a lava troll!",
      "A lava troll melts into a flow of molten lava that rises up and reforms into the lava troll!"
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lava troll swings {weapon} at you!",
        "A lava troll swings a leather-wound ruddy steel sledgehammer at {target}!"
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
