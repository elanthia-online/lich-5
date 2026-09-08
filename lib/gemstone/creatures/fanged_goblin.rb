{
  schema_version: 3,
  name: "fanged goblin",
  noun: "goblin",
  url: "https://gswiki.play.net/fanged_goblin",
  picture: "",
  level: 2,
  family: "Goblin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 50,
  speed: 10,
  height: 3,
  size: "small",
  areas: [
    {
      name: "The Toadwort",
      uids: [14007001..14007022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: (36..46)
      },
      {
        name: "Spear",
        as: (36..46)
      },
      {
        name: "Unknown",
        as: 36
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
    asg: "7",
    immunities: [],
    melee: (-11..68),
    ranged: (-26..4),
    bolt: (-26..4),
    udf: (57..116),
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a handaxe",
    "a leather breastplate",
    "a spear",
    "a wooden shield",
    "some reinforced leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a goblin fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Round-headed with a squat nose and a wide mouth, her features occasionally interrupted by warts, the fanged goblin has a dark cast green skin with a sickly yellow tinge to it. Long, sharp fangs poke out of her puffed lips forcing her face into a perpetual sneer. Standing as tall as a dwarf or halfling, the fanged goblin moves with a nervous energy but rarely looks directly at anyone. A yeasty smell as of molding bread or of something left to rot in a dark damp place completes the goblin's aura of repulsiveness."
    ],
    arrival: [
      "A fanged goblin just arrived!",
      "A fanged goblin meanders in waggling {pronoun} fingers at everything {pronoun} sees.",
      "A fanged goblin rushes in, bows {pronoun} head for a moment and then looks back up.",
      "A fanged goblin marches in!"
    ],
    flee: [
      "A fanged goblin tramps {direction}."
    ],
    death: [
      "The fanged goblin falls to the ground, kicks several times and dies.",
      "The fanged goblin screams silently, shudders one last time and dies.",
      "The fanged goblin screams, shudders one last time and dies."
    ],
    decay: [
      "A fanged goblin's carcass collapses into a gooey mess.",
      "A fanged goblin's remains decompose leaving a horrendous smell in {pronoun} wake."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A fanged goblin swings {weapon} at you!",
        "A fanged goblin thrusts with a spear at you!"
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
