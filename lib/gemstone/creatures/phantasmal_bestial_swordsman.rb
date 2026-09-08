{
  schema_version: 3,
  name: "phantasmal bestial swordsman",
  noun: "swordsman",
  url: "https://gswiki.play.net/phantasmal_bestial_swordsman",
  picture: "",
  level: 62,
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
  bcs: true,
  max_hp: 400,
  speed: 10,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [377301..377314]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hammer of Kai"
      },
      {
        name: "Black steel claidhmore",
        as: 272
      },
      {
        name: "Black steel twohanded sword",
        as: 342
      },
      {
        name: "Rhimar trident",
        as: 345
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Sunder Shield"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (157..391),
    ranged: (171..243),
    bolt: (171..243),
    udf: (314..492),
    bar_td: nil,
    cle_td: (236..245),
    emp_td: (230..233),
    pal_td: (201..213),
    ran_td: 221,
    sor_td: (217..223),
    wiz_td: nil,
    mje_td: (265..268),
    mne_td: (265..268),
    mjs_td: 282,
    mns_td: 282,
    mnm_td: 198,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a black steel twohanded sword",
    "a filthy loin cloth",
    "a set of black steel augmented plate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence",
    armaments: [
      "polished red steel Hammer of Kai"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Muscular and lean, a phantasmal bestial swordsman stands shorter than most giantmen, dressed only in the ragged remains of leather pants. His skin is the color of a starless night and is wrapped tightly around brawny arms and legs. Long, pointed ears extend from the sides of his bald head with large, pitch black eyes set closely together over two large slits in place of a proper nose. Long yellow canines stick up from behind the lower lip of the swordsman."
    ],
    arrival: [
      "A phantasmal bestial swordsman stalks in.",
      "A phantasmal bestial swordsman emerges from the surrounding shadows, the tip of {pronoun} blade drawing through the floor before being raised high above {pronoun} head."
    ],
    flee: [
      "A phantasmal bestial swordsman stalks {direction}."
    ],
    death: [
      "Growling lowly, the bestial swordsman falls to one knee, then collapses to the floor.",
      "The bestial swordsman falls to one knee, then collapses to the floor."
    ],
    decay: [
      "Thin blue lines of magical energy crackle over the body of a phantasmal bestial swordsman before {pronoun} dissolves, leaving a puddle of liquid and the smell of ozone in the air."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A phantasmal bestial swordsman swings {weapon} at you!",
        "A phantasmal bestial swordsman thrusts with a rhimar trident at you!",
        "A phantasmal bestial swordsman swings a black steel twohanded sword at {target}!"
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
