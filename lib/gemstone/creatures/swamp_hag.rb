{
  schema_version: 3,
  name: "swamp hag",
  noun: "hag",
  url: "https://gswiki.play.net/swamp_hag",
  picture: "",
  level: 42,
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
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Miasmal Forest",
      uids: [5004035..5004044, 5004049..5004053]
    },
    {
      name: "unmapped",
      uids: [5004045..5004048, 5004054..5004054]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Slap",
        as: 255
      }
    ],
    bolt_spells: [
      {
        name: "Major Fire (908)",
        as: 235
      }
    ],
    warding_spells: [
      {
        name: "Hand of Tonis (505)",
        cs: 224
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Sandstorm (914)"
      },
      {
        name: "Tremors (909)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Evil Eye"
      },
      {
        name: "Lash"
      },
      {
        name: "Point"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (229..297),
    ranged: (175..223),
    bolt: 309,
    udf: (238..309),
    bar_td: nil,
    cle_td: (149..159),
    emp_td: (148..157),
    pal_td: (133..136),
    ran_td: (116..125),
    sor_td: (155..161),
    wiz_td: nil,
    mje_td: 163,
    mne_td: 163,
    mjs_td: (148..153),
    mns_td: (148..153),
    mnm_td: (143..150),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Focus (513)",
      "Prismatic Guard (905)",
      "Strength (509)",
      "Thurfel's Ward (503)",
      "Wizard Shield (919)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some torn"
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
      "Small and rather unimposing, the swamp hag is a dangerous, magical foe. Her stringy, oiled-flat hair glistens as her eerie, coal-black eyes dart about her surroundings always searching for victims. Bright red sparks scatter from her fingertips whenever she clenches her clawed hands. Dark grey skin and thin emaciated arms and legs provide stark contrast to the hag's distended, bulbous stomach."
    ],
    arrival: [
      "A swamp hag trudges in, a weary mask set on {pronoun} face!"
    ],
    flee: [
      "A swamp hag hobbles {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A swamp hag gestures with a hand and a red-tinged aura grows around {pronoun} hands.",
      "A swamp hag raises {pronoun} hands to chest height and sweeps {pronoun} up, leaving a glowing trace.",
      "A swamp hag mutters a phrase, and as {pronoun} does, a gust of wind sweeps in and flips {pronoun} to {pronoun} feet."
    ],
    attacks: {
      attack: [
        "A swamp hag screams an angry torrent of curses and points at you!",
        "A swamp hag spits out a string of vituperative invectives and points at you!"
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
