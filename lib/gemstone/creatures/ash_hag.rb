{
  schema_version: 3,
  name: "ash hag",
  noun: "hag",
  url: "https://gswiki.play.net/ash_hag",
  picture: "",
  level: 31,
  family: "Witch",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 238,
  speed: 6,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Volcanic Flats",
      uids: [3023001..3023028]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Slap",
        as: 210
      },
      {
        name: "Bite (attack)",
        as: 180
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 200
      }
    ],
    warding_spells: [
      {
        name: "Immolation (519)",
        cs: 183
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Fire Storm"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: (150..240),
    ranged: (139..169),
    bolt: (139..169),
    udf: (181..280),
    bar_td: 110,
    cle_td: (117..123),
    emp_td: (109..118),
    pal_td: (99..108),
    ran_td: (90..99),
    sor_td: (119..128),
    wiz_td: nil,
    mje_td: (135..141),
    mne_td: (135..141),
    mjs_td: (118..126),
    mns_td: (118..126),
    mnm_td: (115..124),
    defensive_spells: [
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Thurfel's Ward (503)"
    ],
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
    gems: true,
    boxes: true,
    skin: "a hag nose",
    other: [
      "glimmering blue essence shard",
      "essence of fire",
      "glimmering blue essence dust"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "An ash hag just arrived, shrieking in pain!"
    ],
    flee: [
      "An ash hag bursts into flame, leaving nothing behind but a cloud of ash that wafts {direction}."
    ],
    death: [
      "The ash hag twitches violently, then dies."
    ],
    decay: [
      "An ash hag crumbles into a pile of ash."
    ],
    search: [],
    spell_prep: [
      "An ash hag utters a fiery incantation."
    ],
    stun_break: [
      "An ash hag eyes burn with bright orange fire as {pronoun} tries to shake off the stun!"
    ],
    attacks: {
      attack: [
        "An ash hag blows a cloud of ash at you!"
      ],
      bite: [
        "An ash hag snaps {pronoun} fingers and blinks out of existence."
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
