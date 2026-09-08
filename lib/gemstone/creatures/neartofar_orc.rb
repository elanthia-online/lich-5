{
  schema_version: 3,
  name: "neartofar orc",
  noun: "orc",
  url: "https://gswiki.play.net/neartofar_orc",
  picture: "",
  level: 11,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  speed: 15,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015001..14015020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: (149..159)
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
    asg: "12",
    immunities: [],
    melee: (55..163),
    ranged: (51..80),
    bolt: (51..80),
    udf: (86..171),
    bar_td: (30..33),
    cle_td: (30..39),
    emp_td: (33..41),
    pal_td: (30..39),
    ran_td: (30..33),
    sor_td: (33..39),
    wiz_td: nil,
    mje_td: (30..36),
    mne_td: (30..36),
    mjs_td: (30..39),
    mns_td: (30..39),
    mnm_td: (27..36),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a cracked leather helm",
    "a reinforced shield",
    "a rusted morning star",
    "some dirt-caked dark iron armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc knuckle",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Taller than a common human and of a substantially heavier build, the Neartofar orc has a build of solid bone and gristle. Piercing, yellow eyes glare angrily out from under a thick ridge of bone on his forehead. Irregular clumps of rank hair litter his oddly striking brown and green hued-body from head to toe. His arms resemble thick and twisted tree trunks, ending in ragged claws crusted with dried gore."
    ],
    arrival: [
      "A Neartofar orc stalks in purposefully, {pronoun} nose raised as {pronoun} sniffs at the air.",
      "A Neartofar orc stalks in!"
    ],
    flee: [
      "A Neartofar orc stalks {direction}.",
      "A neartofar orc hobbles slowly {direction}, uttering a curse under {pronoun} breath."
    ],
    death: [
      "A Neartofar orc breathes {pronoun} last gasp and dies.",
      "A Neartofar orc collapses into a pile of dust."
    ],
    decay: [
      "A Neartofar orc collapses into a pile of dust."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A neartofar orc strains to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A Neartofar orc swings {weapon} at you!",
        "A Neartofar orc swings a rusted morning star at {target}!",
        "A neartofar orc swings a rusted morning star at {target}!",
        "A neartofar orc hunches {pronoun} shoulders and glares at you."
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
