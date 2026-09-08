{
  schema_version: 3,
  name: "spectral warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/spectral_warrior",
  picture: "",
  level: 34,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 300,
  speed: 10,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [2100002..2100056]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 230
      },
      {
        name: "Flail",
        as: (230..250)
      },
      {
        name: "Broadsword",
        as: 250
      },
      {
        name: "Halberd",
        as: (250..288)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm"
      },
      {
        name: "Halberd Sweep"
      }
    ],
    special_abilities: [
      {
        name: "Attack strength boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (147..212),
    ranged: (137..188),
    bolt: (137..188),
    udf: (211..247),
    bar_td: nil,
    cle_td: (96..102),
    emp_td: (102..111),
    pal_td: (99..102),
    ran_td: (102..108),
    sor_td: (93..102),
    wiz_td: nil,
    mje_td: (94..109),
    mne_td: (94..109),
    mjs_td: 102,
    mns_td: 102,
    mnm_td: 102,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Immune to Unbalance"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a battered steel shield",
    "a rusted broadsword",
    "a tarnished flail",
    "an old pitted halberd",
    "some dented augmented chain",
    "some rotting brigandine armor",
    "some rusted steel half plate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The spectral warrior shimmers for an instant, seemingly half real and half phantom, his semi-ethereal armor faintly gleaming as it moves. A gaunt face stares out from beneath the ghostly helm, his eyes swirling pits of blackness that seek out living foes, hatefully wishing to resign others to his own horrible fate."
    ],
    arrival: [
      "A spectral warrior strides in!"
    ],
    flee: [
      "A spectral warrior strides {direction}!"
    ],
    death: [
      "A spectral warrior dissipates into ethereal wisps."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A spectral warrior looses a keening howl, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A spectral warrior swings {weapon} at you!",
        "A spectral warrior swings {pronoun} {weapon} at your mossbark runestaff!",
        "A spectral warrior swings {pronoun} {weapon} at your vultite bastard sword!"
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
