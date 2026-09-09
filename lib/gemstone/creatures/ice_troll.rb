{
  schema_version: 3,
  name: "ice troll",
  noun: "troll",
  url: "https://gswiki.play.net/ice_troll",
  picture: "",
  level: 29,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 235,
  speed: 8,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Glatoph",
      uids: [35005..35009, 35026..35040, 35068..35072]
    },
    {
      name: "Ice Plains",
      uids: [7502001..7502010, 7502016..7502021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Sword",
        as: 228
      },
      {
        name: "Battle-axe",
        as: 205
      },
      {
        name: "Enruned ice-covered battle axe",
        as: 200
      },
      {
        name: "Freezing ball of pure cold",
        as: (179..185)
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 158
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (152..280),
    ranged: (134..179),
    bolt: (134..179),
    udf: (181..285),
    bar_td: (86..91),
    cle_td: 105,
    emp_td: (94..104),
    pal_td: (84..94),
    ran_td: (81..84),
    sor_td: (101..112),
    wiz_td: nil,
    mje_td: (104..109),
    mne_td: (104..109),
    mjs_td: 122,
    mns_td: 122,
    mnm_td: (87..90),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a badly torn rusted chain hauberk",
    "a massive icicle",
    "an enruned ice-covered battle axe",
    "an ice club",
    "an ice spear",
    "an ice-covered two-handed sword",
    "an ice-crusted steel chain hauberk"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ice troll scalp",
    other: [
      "essence of water, small troll tooth",
      "glimmering blue essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glistening in the light, the troll's ice white skin is covered in slush and snow. Seemingly carved from living ice, the ice troll is a stark, imposing creature. Instead of hair, the ice troll has a field of icicles growing from its head and face."
    ],
    arrival: [],
    flee: [],
    death: [
      "The ice troll cries out in cold agony one last time and dies.",
      "The ice troll falls to the ground motionless.",
      "The ice troll screams evilly one last time and goes still."
    ],
    decay: [
      "An ice troll melts into a puddle of slush which sloshes {direction}."
    ],
    search: [
      "An ice troll looks around apprehensively as {pronoun} starts to melt!"
    ],
    spell_prep: [],
    stand: [
      "An ice troll throws {pronoun} head back and howls, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "An ice troll swings {weapon} at you!",
        "An ice troll blows {pronoun} icy breath at you!"
      ],
      hurl: [
        "An ice troll hurls {weapon} at you!"
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
