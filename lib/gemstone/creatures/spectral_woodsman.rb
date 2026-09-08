{
  schema_version: 3,
  name: "spectral woodsman",
  noun: "woodsman",
  url: "https://gswiki.play.net/spectral_woodsman",
  picture: "",
  level: 35,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124106..4124112, 4124114..4124115, 4124125..4124128]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe"
      },
      {
        name: "Hissing stream of acid",
        as: 192
      },
      {
        name: "Powerful lightning bolt",
        as: 172
      },
      {
        name: "Roaring ball of fire",
        as: 176
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
    melee: (145..268),
    ranged: (144..190),
    bolt: (144..190),
    udf: (269..327),
    bar_td: nil,
    cle_td: (121..131),
    emp_td: (124..134),
    pal_td: (103..112),
    ran_td: (102..112),
    sor_td: (125..146),
    wiz_td: nil,
    mje_td: 144,
    mne_td: (135..159),
    mjs_td: (131..140),
    mns_td: (131..140),
    mnm_td: (107..116),
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
  equipment: [
    "a bruised left eye",
    "a rusty woodsman's axe",
    "a tattered plaid flannel shirt",
    "a weathered plaid flannel cap",
    "some heavy leather boots",
    "some torn woodsman's leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "Glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The spectral woodsman floats through the forests it once knew in life, but the forests no longer know it. Now locked into an undead state, the spectral woodsman is merely a shade of its former self. The woodsman's sunken eyes stare out from darkened sockets and its long, unkempt hair flutters wildly as if in a strong wind. The spectral woodsman unceasingly seeks to destroy the living. If it cannot return to life, perhaps making everything dead will bring it all back to it."
    ],
    arrival: [],
    flee: [
      "A spectral woodsman floats {direction}."
    ],
    death: [
      "A spectral woodsman fades into oblivion."
    ],
    decay: [
      "A spectral woodsman fades into oblivion."
    ],
    search: [],
    spell_prep: [
      "A spectral woodsman utters a phrase of arcane magic."
    ],
    attacks: {
      attack: [
        "A spectral woodsman nods at you!",
        "A spectral woodsman swings {weapon} at you!",
        "A spectral woodsman swings a rusty woodsman's axe at {target}!"
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
