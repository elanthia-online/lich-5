{
  schema_version: 3,
  name: "Ithzir janissary",
  noun: "janissary",
  url: "https://gswiki.play.net/ithzir_janissary",
  picture: "",
  level: 92,
  family: "Ithzir",
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
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: 7,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004001..17004028, 17004031..17004079, 17004160..17004168, 17004180..17004187, 17004190..17004195]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 428
      },
      {
        name: "Military fork"
      },
      {
        name: "Mace",
        as: 421
      },
      {
        name: "Smash",
        as: 453
      },
      {
        name: "Spiral-hafted crystal-edged handaxe",
        as: (402..423)
      },
      {
        name: "Spiral-hafted handaxe",
        as: (413..421)
      },
      {
        name: "Twisted crystal-tipped staff",
        as: 431
      },
      {
        name: "Gleaming crystal-edged broadsword",
        as: 413
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
        name: "Warcries"
      },
      {
        name: "Disarm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (207..490),
    ranged: (160..397),
    bolt: (160..397),
    udf: (431..485),
    bar_td: 299,
    cle_td: (337..346),
    emp_td: (338..344),
    pal_td: (275..284),
    ran_td: 299,
    sor_td: (353..368),
    wiz_td: nil,
    mje_td: (376..436),
    mne_td: (376..436),
    mjs_td: 408,
    mns_td: 408,
    mnm_td: 291,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blued steel hauberk",
    "a polished steel shield",
    "a spiral-hafted crystal-edged handaxe",
    "a spiral-hafted handaxe"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "crystal-edged weapons",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "An Ithzir janissary swings {weapon} at you!",
        "The Ithzir janissary points at you for emphasis.",
        "The Ithzir janissary points at you.",
        "An Ithzir janissary swings a spiral-hafted crystal-edged handaxe at {target}!",
        "An Ithzir janissary swings a twisted crystal-tipped staff at {target}!",
        "An Ithzir janissary swings {pronoun} {weapon} at your vultite handaxe!",
        "An Ithzir janissary swings {pronoun} {weapon} at your smooth glowbark staff!",
        "An Ithzir janissary swings a gleaming crystal-edged broadsword at {target}!"
      ]
    },
    stand: [
      "An Ithzir janissary rises to {pronoun} feet, {pronoun} green eyes blazing!"
    ],
    description: [
      "The Ithzir janissary's movements are both aggressive and graceful, his muscular, lithe form the envy of any acrobat or student of the martial arts. Wide, upward-slanted, green eyes take in his surroundings with an easy confidence, as if the fate of any opponent is not a matter of chance, only of time. The Ithzir janissary is a head taller than a human, and while his humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance. The janissary wears a crisply-cut silvery blue tunic emblazoned with a feline silhouette on the right breast."
    ],
    arrival: [
      "An Ithzir janissary strides in, surveying the surroundings alertly."
    ],
    flee: [
      "An Ithzir janissary strides {direction}.",
      "An Ithzir janissary slowly backs away with {pronoun} handaxe brandished menacingly in front of {pronoun}.",
      "An Ithzir janissary slowly backs away with {pronoun} crystal-edged handaxe brandished menacingly in front of {pronoun}.",
      "An Ithzir janissary strides out of thin air!"
    ],
    death: [
      "The Ithzir janissary vainly struggles to rise, then goes still.",
      "Just as you cast, the Ithzir janissary shimmers and fades away, leaving you gesturing at nothingness!",
      "An Ithzir janissary's body shimmers slightly, then fades from view like a dissipating phantom."
    ],
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
