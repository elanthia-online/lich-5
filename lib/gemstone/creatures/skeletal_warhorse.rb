{
  schema_version: 3,
  name: "skeletal warhorse",
  noun: "warhorse",
  url: "https://gswiki.play.net/skeletal_warhorse",
  picture: "",
  level: 37,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: "boss",
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Castle Varunar",
      uids: [4750034..4750039, 4750071..4750076]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 262
      },
      {
        name: "Stomp",
        as: 240
      },
      {
        name: "Foot",
        as: 235
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (142..248),
    ranged: (140..214),
    bolt: (140..214),
    udf: 220,
    bar_td: nil,
    cle_td: (108..114),
    emp_td: (111..120),
    pal_td: (102..114),
    ran_td: (111..120),
    sor_td: (102..114),
    wiz_td: nil,
    mje_td: 111,
    mne_td: 111,
    mjs_td: (111..120),
    mns_td: (111..120),
    mnm_td: (111..114),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a rusted steel chanfron",
    "some rotting studded leather barding",
    "some rusted steel barding"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a skeletal warhorse jaw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A bulky skeleton belies the skeletal warhorse's speed and quick reflexes. Even encased in heavy steel barding and lacking its muscular body, the warhorse charges, stomps and bites with the same ferocity it displayed in life. Now, long decomposed, its hide has turned to a moldy gray and the once-proud mane hangs in tattered strands."
    ],
    arrival: [
      "A skeletal warhorse just arrived."
    ],
    flee: [
      "A skeletal warhorse gallops {direction}.",
      "A skeletal warhorse just went through a soot-stained wooden door.",
      "A skeletal warhorse just went through some barn doors.",
      "A skeletal warhorse just went through a stout wooden door.",
      "A skeletal warhorse slowly trots east, whinnying in pain."
    ],
    death: [
      "The skeletal warhorse falls to the ground motionless.",
      "The skeletal warhorse wails in terrifying pain one last time and lies still.",
      "The skeletal warhorse falls to the ground dead, {pronoun} calcified bones still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeletal warhorse charges at you!",
        "A skeletal warhorse stomps at you with {pronoun} foot!"
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
