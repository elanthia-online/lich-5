{
  schema_version: 3,
  name: "lesser mummy",
  noun: "mummy",
  url: "https://gswiki.play.net/lesser_mummy",
  picture: "",
  level: 6,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 88,
  speed: 18,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [18013..18021, 2138001..2138018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 108
      },
      {
        name: "Ensnare",
        as: 118
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
    melee: (34..70),
    ranged: (18..63),
    bolt: (18..63),
    udf: (49..60),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: nil,
    ran_td: 18,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 18,
    mns_td: 18,
    mnm_td: 18,
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
    skin: "a mummy shroud",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser mummy scrapes slowly across the floor, dragging its form tirelessly in an attempt to find final rest. Its decayed flesh is barely contained in the remnants of its embalming strips, torn and unwrapping in its wake. Once a member of a proud and wealthy family, it has left its sarcophagus to discover someone who can help it and to kill all those who cannot."
    ],
    arrival: [
      "A lesser mummy just arrived!",
      "A lesser mummy just arrived."
    ],
    flee: [],
    death: [
      "The lesser mummy falls to the ground motionless.",
      "The lesser mummy screams evilly one last time and goes still."
    ],
    decay: [
      "A lesser mummy turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser mummy tries to ensnare you!"
      ],
      claw: [
        "A lesser mummy claws at you!"
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
