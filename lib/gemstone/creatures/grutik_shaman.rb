{
  schema_version: 3,
  name: "grutik shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/grutik_shaman",
  picture: "",
  level: 29,
  family: "Grutik",
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
    "Living"
  ],
  bcs: true,
  max_hp: 235,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Zaerthu Tunnels",
      uids: [13009001..13009039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 220
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 205
      }
    ],
    warding_spells: [
      {
        name: "Sleep (501)",
        cs: 165
      },
      {
        name: "Burrow Ambush",
        cs: 165
      },
      {
        name: "Gnarled wooden staff",
        cs: 165
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Dispel (417)"
      },
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Tremors (909)"
      }
    ],
    maneuvers: [
      {
        name: "Gesture"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (241..282),
    ranged: (182..215),
    bolt: (182..255),
    udf: (255..339),
    bar_td: 95,
    cle_td: (105..111),
    emp_td: (107..115),
    pal_td: (83..89),
    ran_td: (83..92),
    sor_td: (111..117),
    wiz_td: 115,
    mje_td: 115,
    mne_td: 115,
    mjs_td: (104..113),
    mns_td: (104..113),
    mnm_td: (93..103),
    defensive_spells: [
      "Prismatic Guard (905)",
      "Mass Blur (911)",
      "Elemental Bias (508)",
      "Elemental Deflection (507)",
      "Thurfel's Ward (503)",
      "Wizard's Shield (919)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude roa'ter-toothed necklace",
    "a dirty tattered robe",
    "a gnarled wooden staff"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "glimmering blue mote of essence",
      "glimmering blue essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A Grutik shaman finishes the chant and gestures at you!"
      ]
    },
    stand: [
      "A Grutik shaman stands up.",
      "A grutik shaman stands up."
    ],
    description: [
      "This misshapen humanoid has large luminous eyes from many years of living underground. It's dressed in scraps of mismatched cloth in an apparent attempt to make a crude patchwork robe. While not overly muscled, its eyes shine with a crude intelligence."
    ],
    arrival: [
      "A Grutik shaman shambles in."
    ],
    flee: [
      "A Grutik shaman shambles {direction}.",
      "A Grutik shaman stands {direction}."
    ],
    death: [
      "The Grutik shaman twitches violently, then dies.",
      "A Grutik shaman collapses into a lifeless heap upon the ground."
    ],
    decay: [
      "A Grutik shaman collapses into a lifeless heap upon the ground.",
      "A Grutik shaman's body turns to dust."
    ],
    search: [],
    spell_prep: [],
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
