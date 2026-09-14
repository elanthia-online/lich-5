{
  schema_version: 3,
  name: "wall guardian",
  noun: "guardian",
  url: "https://gswiki.play.net/wall_guardian",
  picture: "",
  level: 11,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 138,
  speed: 9,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7531001..7531042]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Military pick",
        as: 153
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
    asg: "16",
    immunities: [],
    melee: (59..144),
    ranged: (46..79),
    bolt: (46..79),
    udf: (76..171),
    bar_td: 27,
    cle_td: (30..39),
    emp_td: (33..41),
    pal_td: (30..39),
    ran_td: (30..33),
    sor_td: (27..33),
    wiz_td: nil,
    mje_td: 33,
    mne_td: 33,
    mjs_td: (27..39),
    mns_td: (27..39),
    mnm_td: (30..39),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a coral-shafted military pick",
    "a salt-stained chain hauberk"
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
      "The wall guardian is a bit taller than a halfling, but not by much. Filthy, stinky and smelly, she looks as if she hasn't bathed in years. A faint smirk is etched on the face of the guardian."
    ],
    arrival: [
      "A wall guardian marches in.",
      "A wall guardian rushes in with a shout!"
    ],
    flee: [],
    death: [
      "The wall guardian vainly tries to shout a warning, then goes still."
    ],
    decay: [
      "The wall guardian decays into a grisly pile of armor, blood, and bone."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A wall guardian holds {pronoun} head as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      attack: [
        "A wall guardian swings {weapon} at you!",
        "A wall guardian charges into view, a surprised look on {pronoun} face!",
        "A wall guardian swings a coral-shafted military pick at {target}!"
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
