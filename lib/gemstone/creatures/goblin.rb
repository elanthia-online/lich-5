{
  schema_version: 3,
  name: "goblin",
  noun: "goblin",
  url: "https://gswiki.play.net/goblin",
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
  max_hp: 49,
  speed: 10,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Old Mine Road",
      uids: [20001..20035]
    },
    {
      name: "The Graveyard",
      uids: [18003..18011]
    },
    {
      name: "Upper Trollfang",
      uids: [16001..16020]
    },
    {
      name: "Sea Caverns",
      uids: [391001..391022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 46
      },
      {
        name: "Scimitar",
        as: 36
      },
      {
        name: "Unknown",
        as: 46
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
    asg: "5",
    immunities: [],
    melee: (44..68),
    ranged: (-21..17),
    bolt: 6,
    udf: (26..102),
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
    special_defenses: [
      "Hides when attacked"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a flail",
    "a handaxe",
    "a leather breastplate",
    "a leather helm",
    "a morning star",
    "a scimitar",
    "a spear",
    "a wooden shield",
    "some cuirbouilli leather",
    "some leather boots",
    "some light leather",
    "some reinforced leather",
    "some studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a goblin's ",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Round-headed with a squat nose and a wide mouth, the goblin has greenish skin with a sickly yellow cast over all. Roughly as tall as a dwarf or halfling, the goblin moves with a nervous energy but rarely looks directly at you. A yeasty smell as of molding bread or of something left to rot in a dark damp place completes the goblin's aura of repulsivenss."
    ],
    arrival: [
      "A goblin meanders in waggling {pronoun} fingers at everything {pronoun} sees.",
      "A goblin rushes in, bows {pronoun} head for a moment and then looks back up.",
      "A goblin marches in!"
    ],
    flee: [
      "A goblin tramps {direction}."
    ],
    death: [
      "The goblin falls to the ground, kicks several times and dies.",
      "The goblin screams, shudders one last time and dies.",
      "The goblin twitches violently, then dies."
    ],
    decay: [
      "A goblin's carcass collapses into a gooey mess.",
      "A goblin's remains decompose leaving a horrendous smell in {pronoun} wake."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A goblin swings {weapon} at you!",
        "A goblin swings a scimitar at {target}!",
        "A goblin swings a morning star at {target}!"
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
