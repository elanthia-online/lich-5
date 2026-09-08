{
  schema_version: 3,
  name: "lesser minotaur",
  noun: "minotaur",
  url: "https://gswiki.play.net/lesser_minotaur",
  picture: "",
  level: 74,
  family: "Minotaur",
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
  max_hp: 300,
  speed: nil,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "The Hidden Plateau",
      uids: [2167001..2167031, 2167033..2167040, 2167050..2167067, 2167111..2167122]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Greataxe",
        as: 338
      },
      {
        name: "Waraxe",
        as: (341..376)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Bull Rush"
      },
      {
        name: "Feint"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (257..495),
    ranged: (183..355),
    bolt: (183..355),
    udf: (357..561),
    bar_td: (239..251),
    cle_td: (254..269),
    emp_td: (255..261),
    pal_td: (210..234),
    ran_td: (219..222),
    sor_td: (261..285),
    wiz_td: nil,
    mje_td: (288..299),
    mne_td: (288..299),
    mjs_td: (249..267),
    mns_td: (249..267),
    mnm_td: (225..234),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broad leather-wrapped waraxe",
    "a bruised left eye",
    "a bruised right eye",
    "a curved silvery white greataxe",
    "a reinforced slatted wooden shield",
    "some rough dark grey brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur hide",
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser minotaur is an ugly, brutish looking beast. Taller than most average men, the minotaur has a bull-like appearance while his muscular body is humanoid with thick arms and broad shoulders. The lesser minotaur feet end in hooves that rattle the ground with every step. Despite his barbaric features, a great intelligence is reflected in the depths of his eyes and mannerisms."
    ],
    arrival: [
      "A lesser minotaur stomps in!",
      "A lesser minotaur stomps in, squinting warily."
    ],
    flee: [
      "The lesser minotaur lumbers {direction}."
    ],
    death: [
      "A low gurgling sound comes from deep within the chest of the lesser minotaur as he falls slack against the ground.",
      "A low gurgling sound comes from deep within the chest of the lesser minotaur as he falls slack against the floor."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser minotaur swings {weapon} at you!",
        "A lesser minotaur swings a curved silvery white greataxe at {target}!"
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
