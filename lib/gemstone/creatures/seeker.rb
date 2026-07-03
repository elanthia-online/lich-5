{
  schema_version: 3,
  name: "seeker",
  noun: "",
  url: "https://gswiki.play.net/seeker",
  picture: "",
  level: 52,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Mount Aenatumgana",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Gas cloud"
      },
      {
        name: "Strength (509)"
      },
      {
        name: "Elemental Dispel"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: (273..337),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 216,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 246,
    mne_td: nil,
    mjs_td: 201,
    mns_td: 201,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Mass Blur (911)",
      "Prismatic Guard (905)"
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
    skin: "a seeker eye",
    other: "[[Glowing violet mote of essence]]"
  },
  messaging: {
    description: [
      "Approaching from afar, the seeker looks for all the world like a hunched over traveller, barely getting by with the aid of her walking stick, shuffling along and muttering to herself.  Upon close examination, though, the seeker projects a grisly visage of skeletal madness.  Some strange magic has caused her eyelids to grow completely over her eyes, rendering her blind, yet the rest of her face is totally fleshless.  Grinning fiendishly, the seeker unerringly pursues her goal - the Eye of the Drake and the path through to the Rift."
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
