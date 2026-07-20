{
  schema_version: 3,
  name: "spectral woodsman",
  noun: "",
  url: "https://gswiki.play.net/spectral_woodsman",
  picture: "",
  level: 35,
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
      name: "Icemule Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: "194 to 219"
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 212
      },
      {
        name: "Major Cold (907)",
        as: 212
      },
      {
        name: "Major Fire (908)",
        as: 218
      },
      {
        name: "Major Shock (910)",
        as: 218
      }
    ],
    warding_spells: [
      {
        name: "Repel(fear)",
        cs: 188
      },
      {
        name: "Mind blanked?",
        cs: 195
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gas cloud"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: 250,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "125 to146",
    wiz_td: nil,
    mje_td: nil,
    mne_td: "135 to 159",
    mjs_td: nil,
    mns_td: 131,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Presence (402)",
      "Elemental Defense II (406)",
      "Thurfel's Ward (503)",
      "Celerity (506)"
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
    boxes: nil,
    skin: nil,
    other: "Glowing violet essence dust"
  },
  messaging: {
    description: [
      "The spectral woodsman floats through the forests it once knew in life, but the forests no longer know it. Now locked into an undead state, the spectral woodsman is merely a shade of its former self. The woodsman's sunken eyes stare out from darkened sockets and its long, unkempt hair flutters wildly as if in a strong wind. The spectral woodsman unceasingly seeks to destroy the living. If it cannot return to life, perhaps making everything dead will bring it all back to it."
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
