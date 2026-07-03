{
  schema_version: 3,
  name: "grutik shaman",
  noun: "",
  url: "https://gswiki.play.net/grutik_shaman",
  picture: "",
  level: 29,
  family: "Grutik",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Zaerthu Tunnels",
      rooms: []
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
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5N",
    immunities: [],
    melee: (221..271),
    ranged: nil,
    bolt: (205..255),
    udf: (230..280),
    bar_td: 95,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: 115,
    mje_td: 115,
    mne_td: 115,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "This misshapen humanoid has large luminous eyes from many years of living underground. It's dressed in scraps of mismatched cloth in an apparent attempt to make a crude patchwork robe. While not overly muscled, its eyes shine with a crude intelligence."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
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
