{
  schema_version: 3,
  name: "hobgoblin shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/hobgoblin_shaman",
  picture: "",
  level: 7,
  family: "Goblin",
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
  max_hp: 80,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Ocoma Vale",
      uids: [4300012..4300025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leather whip",
        as: 111
      },
      {
        name: "Mace",
        as: 111
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 89
      },
      {
        name: "Minor Water (903)",
        as: 89
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (24..92),
    ranged: 19,
    bolt: 19,
    udf: (31..86),
    bar_td: 24,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: (18..28),
    sor_td: 20,
    wiz_td: nil,
    mje_td: (19..20),
    mne_td: (19..20),
    mjs_td: 18,
    mns_td: 18,
    mnm_td: 28,
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bone vest",
    "a leather whip",
    "a lynx skull",
    "a twisted modwir short-staff"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a shaman ear",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The shaman has a surprisingly intelligent look for a hobgoblin shaman, though he is no less primitive and vicious than his tribesmen. His voice seems to be constantly uttering the harsh, guttural prayers that appease his barbaric deity. The fervor in the shaman's heart is clear from the frenzied gleam in his eyes."
    ],
    arrival: [],
    flee: [
      "A hobgoblin shaman struts {direction}.",
      "A hobgoblin shaman hobbles slowly {direction}, uttering a prayer under {pronoun} breath."
    ],
    death: [
      "The hobgoblin shaman screams up at the heavens, then collapses and dies.",
      "The hobgoblin shaman struggles to utter a final prayer, then goes still.",
      "The hobgoblin shaman twitches violently before finally going still."
    ],
    decay: [
      "A hobgoblin shaman decays into a pile of compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A hobgoblin shaman finishes chanting and thrusts {weapon} towards you!",
        "A hobgoblin shaman raises a clenched fist into the air!"
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
