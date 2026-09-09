{
  schema_version: 3,
  name: "gaudy phantasmic conjurer",
  noun: "conjurer",
  url: "https://gswiki.play.net/gaudy_phantasmic_conjurer",
  picture: "",
  level: 106,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
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
  max_hp: 325,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Moonsedge",
      uids: [4577106..4577123, 4577201..4577214, 4577216..4577249]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (520..547)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "458 CS"
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (527..735),
    ranged: (531..754),
    bolt: (531..754),
    udf: (376..657),
    bar_td: (544..574),
    cle_td: 561,
    emp_td: 561,
    pal_td: (521..527),
    ran_td: (521..524),
    sor_td: 558,
    wiz_td: nil,
    mje_td: 476,
    mne_td: 476,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Prismatic Guard (905)",
      "Melgorehn's Aura (913)",
      "Wizard's Shield (919)",
      "Mage Armor (520)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a glowing ethereal staff capped with a flickering crystal sphere"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A gaudy phantasmic conjurer stalks in impatiently, {pronoun} gaudy robes drifting several inches above the floor.",
      "A gaudy phantasmic conjurer just came through some vaulting grey stone doors.",
      "A gaudy phantasmic conjurer just came through a heavy steel portcullis."
    ],
    flee: [
      "A gaudy phantasmic conjurer just went through some vaulting grey stone doors.",
      "A gaudy phantasmic conjurer just went through a heavy steel portcullis."
    ],
    death: [],
    decay: [
      "Groans and cracks emanate from an infernal death knight's armor as {pronoun} suddenly succumbs to metal fatigue.  Within seconds, {pronoun} skeletal form collapses into blanched powder and blows away."
    ],
    search: [
      "A gaudy phantasmic conjurer glances around, a suspicious look on {pronoun} translucent features."
    ],
    spell_prep: [],
    attacks: {
      creature_spell: [
        "A gaudy phantasmic conjurer glares malevolently at {target}."
      ],
      bolt: [
        "A gaudy phantasmic conjurer hurls a freezing ball of pure cold at {target}!"
      ],
      attack: [
        "A gaudy phantasmic conjurer shouts out a single mystical syllable, thrusting {pronoun} ghostly hands at you!"
      ],
      wand: [
        "With an artful flick of {pronoun} wrist, a {pronoun} flourishes a filigreed golden wand at you.  A roaring ball of liquid fire erupts toward you!"
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
