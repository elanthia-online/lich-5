{
  schema_version: 3,
  name: "phantasma",
  noun: "",
  url: "https://gswiki.play.net/phantasma",
  picture: "",
  level: 42,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Varunar",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leather whip",
        as: 217
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 201
      },
      {
        name: "Disintegrate (705)",
        cs: 195
      },
      {
        name: "Pain (711)",
        cs: 207
      },
      {
        name: "Curse (715)",
        cs: 201
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Moan"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: 228,
    ranged: 216,
    bolt: 222,
    udf: nil,
    bar_td: "130 to 135",
    cle_td: 161,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "160 to 185",
    wiz_td: nil,
    mje_td: nil,
    mne_td: 169,
    mjs_td: nil,
    mns_td: 158,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)"
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
    other: "Glowing violet mote of essence"
  },
  messaging: {
    description: [
      "A barely visible spirit, the phantasma floats silently across the room. Its bald head, thick neck, muscular forearms and fixed sneer reflect its former positions of jailer and torturer. Rotting leather armor drapes the phantasma, providing it with its only solid link to the living past."
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
