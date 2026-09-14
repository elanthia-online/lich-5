{
  schema_version: 3,
  name: "lesser wood sprite",
  noun: "sprite",
  url: "https://gswiki.play.net/lesser_wood_sprite",
  picture: "",
  level: 30,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 230,
  speed: nil,
  height: 3,
  size: "tiny",
  areas: [
    {
      name: "Sorcerer's Isle",
      uids: [14202001..14202023]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Estoc",
        as: (190..222)
      },
      {
        name: "Composite bow"
      },
      {
        name: "Impale",
        as: 198
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9N",
    immunities: [],
    melee: (190..286),
    ranged: nil,
    bolt: nil,
    udf: (195..316),
    bar_td: 55,
    cle_td: nil,
    emp_td: (140..150),
    pal_td: (110..120),
    ran_td: nil,
    sor_td: (74..82),
    wiz_td: nil,
    mje_td: (49..109),
    mne_td: (49..109),
    mjs_td: (111..117),
    mns_td: (111..117),
    mnm_td: (117..125),
    defensive_spells: [
      "Lesser Shroud (120)",
      "Natural Colors (601)",
      "Phoen's Strength (606)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a pitted iron falchion",
    "a pitted iron jeddart-axe",
    "a wood buckler",
    "a wood composite bow",
    "a wood-gripped estoc"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Pristine sprite's hairGlowing violet essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Appearing more like an animated stick figure than a fleshy humanoid, the slight brown form of the lesser wood sprite stands just over two feet. Her eyes, two sparkling almond-shapes in her wood-like visage, belie a fervent sort of insanity as a frantic, incomprehensible whispering issues from her small mouth."
    ],
    arrival: [
      "Seemingly from nowhere, a lesser wood sprite wanders in!"
    ],
    flee: [
      "A lesser wood sprite glances around and then wanders {direction}!"
    ],
    death: [
      "The lesser wood sprite twitches violently, then dies.",
      "The lesser wood sprite's eyes grow dim as {pronoun} lifeforce fades away."
    ],
    decay: [
      "A lesser wood sprite crumbles into a pile of dry splinters."
    ],
    search: [
      "A lesser wood sprite glances around and then wanders down!",
      "A lesser wood sprite glances around and then wanders up!"
    ],
    spell_prep: [
      "A lesser wood sprite's eyes glow brightly, and {pronoun} motions to you!"
    ],
    attacks: {
      attack: [
        "A lesser wood sprite thrusts with a wood-gripped estoc at you!",
        "A lesser wood sprite swings a pitted iron falchion at you!"
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
