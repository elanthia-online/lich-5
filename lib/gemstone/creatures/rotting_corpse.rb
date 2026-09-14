{
  schema_version: 3,
  name: "rotting corpse",
  noun: "corpse",
  url: "https://gswiki.play.net/rotting_corpse",
  picture: "",
  level: 32,
  family: "Zombie",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Castle Varunar",
      uids: [4750006..4750029]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scythe",
        as: (236..266)
      },
      {
        name: "Bite (attack)",
        as: 233
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
    asg: "9N",
    immunities: [],
    melee: 230,
    ranged: (177..204),
    bolt: (177..204),
    udf: 256,
    bar_td: nil,
    cle_td: (108..117),
    emp_td: (109..113),
    pal_td: (90..96),
    ran_td: (90..99),
    sor_td: (105..123),
    wiz_td: 120,
    mje_td: (119..120),
    mne_td: (119..120),
    mjs_td: 109,
    mns_td: 109,
    mnm_td: 96,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a rusted wheat scythe",
    "some tattered rags"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Stumbling, staggering, cartwheeling wildly, the rotting corpse moves like a large marionette controlled by a drunken hand. Bits of flesh, sinew and disintegrating rags hang from its bony humanoid skeleton. The corpse hunts the living relentlessly, driven by an envy of the living world apparent in her hate-filled eyes."
    ],
    arrival: [
      "A rotting corpse shambles in!"
    ],
    flee: [
      "A rotting corpse shambles {direction}."
    ],
    death: [
      "The rotting corpse wails in terrifying pain one last time and lies still."
    ],
    decay: [
      "A rotting corpse rots away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A rotting corpse swings {weapon} at you!"
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
