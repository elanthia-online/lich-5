{
  schema_version: 3,
  name: "swamp hag",
  noun: "",
  url: "https://gswiki.play.net/swamp_hag",
  picture: "",
  level: 42,
  family: "Witch",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Miasmal Forest",
      rooms: []
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
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 309,
    udf: nil,
    bar_td: nil,
    cle_td: 159,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 161,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
      "Small and rather unimposing, the swamp hag is a dangerous, magical foe.  Her stringy, oiled-flat hair glistens as her eerie, coal-black eyes dart about her surroundings always searching for victims.  Bright red sparks scatter from her fingertips whenever she clenches her clawed hands.  Dark grey skin and thin emaciated arms and legs provide stark contrast to the hag's distended, bulbous stomach."
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
