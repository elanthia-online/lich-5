{
  schema_version: 3,
  name: "skeletal lord",
  noun: "lord",
  url: "https://gswiki.play.net/skeletal_lord",
  picture: "",
  level: 41,
  family: "Humanoid",
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
  boss_type: "boss",
  otherclass: [
    "corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: 11,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Castle Varunar",
      uids: [4750031..4750056, 4750058..4750069]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Lance",
        as: 274
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Trip"
      },
      {
        name: "Disarm"
      },
      {
        name: "Polearm Plant"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "13",
    immunities: [],
    melee: (161..267),
    ranged: (183..260),
    bolt: (183..260),
    udf: (243..347),
    bar_td: 123,
    cle_td: (123..132),
    emp_td: (123..132),
    pal_td: (120..126),
    ran_td: (114..123),
    sor_td: (130..136),
    wiz_td: nil,
    mje_td: 138,
    mne_td: 138,
    mjs_td: (120..129),
    mns_td: (120..129),
    mnm_td: (123..129),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a splintered lance",
    "a tarnished visored helm",
    "a tattered flowing cloak",
    "some rusting chain mail",
    "some tattered riding boots"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The skeletal lord still stands proudly erect. Skilled in the art of battle, it takes its time, carefully measuring each powerful attack to strike at the enemy's most exposed point. Its body reduced to shreds of flesh, eye sockets now empty, the skeletal lord still attacks with amazing accuracy."
    ],
    arrival: [
      "A skeletal lord shambles in!"
    ],
    flee: [
      "A skeletal lord shambles {direction}.",
      "A skeletal lord wails madly as it limps {direction}.",
      "A skeletal lord just went through some barn doors.",
      "A skeletal lord just went through a stout wooden door.",
      "A skeletal lord just went through a stone arch."
    ],
    death: [
      "The skeletal lord falls to the ground motionless.",
      "The skeletal lord wails in terrifying pain one last time and lies still.",
      "The skeletal lord falls to the floor dead, {pronoun} calcified bones still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeletal lord thrusts with a splintered lance at you!",
        "A skeletal lord swings {pronoun} {weapon} at your vultite handaxe!",
        "A skeletal lord swings {pronoun} {weapon} at your mossbark runestaff!"
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
