{
  schema_version: 3,
  name: "hobgoblin",
  noun: "hobgoblin",
  url: "https://gswiki.play.net/hobgoblin",
  picture: "",
  level: 3,
  family: "Goblin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 60,
  speed: 15,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [18018..18028, 18037..18040, 18042..18044, 18048..18052, 2162001..2162015]
    },
    {
      name: "Upper Dragonsclaw",
      uids: [8001..8009, 2121001..2121013, 4121001..4121020]
    },
    {
      name: "unmapped",
      uids: [18041..18041, 18045..18047, 7128016..7128025]
    },
    {
      name: "Southern Snowfields",
      uids: [4128018..4128024]
    },
    {
      name: "Ocoma Vale",
      uids: [4300001..4300025]
    },
    {
      name: "Cairnfang",
      uids: [4745040..4745050]
    },
    {
      name: "Muddy Village",
      uids: [7128001..7128015, 7128026..7128030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claidhmore",
        as: 68
      },
      {
        name: "Handaxe",
        as: 68
      },
      {
        name: "Rapier",
        as: 68
      },
      {
        name: "Iron battle axe",
        as: 58
      },
      {
        name: "Morning star",
        as: 54
      },
      {
        name: "Unknown",
        as: 68
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
    asg: nil,
    immunities: [],
    melee: (-6..93),
    ranged: (-20..14),
    bolt: (-20..14),
    udf: (34..111),
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: (27..34),
    mns_td: (27..34),
    mnm_td: 9,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a chain hauberk",
    "a claidhmore",
    "a feather decorated bone spear",
    "a leather breastplate",
    "a leather helm",
    "a leather skull cap",
    "a metal aventail",
    "a morning star",
    "a rapier",
    "a visored helm",
    "a wooden shield",
    "an iron battle axe",
    "some cuirbouilli leather",
    "some leather boots",
    "some reinforced leather",
    "some woven bead armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a hobgoblin scalp",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This is a large humanoid creature, similar to its smaller cousin the goblin. It has a snub nose and wide mouth with large and very sharp teeth and a greenish-yellow, leathery skin. Reputed to be uncommonly fond of collecting treasure, these are among the most hunted beings known to exist. But many are the whitening skulls that adorn the crude dwellings of the hobgoblin, for treasure is not all they collect."
    ],
    arrival: [
      "A hobgoblin rushes in, howling with rage!"
    ],
    flee: [
      "A hobgoblin snarls as {pronoun} retreats!",
      "A hobgoblin flees {direction}.",
      "A hobgoblin hobbles slowly {direction}, howling in pain."
    ],
    death: [
      "The hobgoblin crumples to the ground and dies.",
      "The hobgoblin lets out a final scream and goes still."
    ],
    decay: [
      "A hobgoblin decays into a pile of compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      cast: [
        "A hobgoblin points a stubby, clawed finger at you as {pronoun} snarls, \"Go 'way!\""
      ],
      attack: [
        "A hobgoblin swings {weapon} at you!",
        "A hobgoblin thrusts with a rapier at you!",
        "A hobgoblin swings a morning star at {target}!",
        "A hobgoblin thrusts with a feather decorated bone spear at you!",
        "A hobgoblin growls at you!"
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
