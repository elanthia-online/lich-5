{
  schema_version: 3,
  name: "minotaur warrior",
  noun: "",
  url: "https://gswiki.play.net/minotaur_warrior",
  picture: "",
  level: 76,
  family: "Minotaur",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehntoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Greataxe",
        as: 368
      },
      {
        name: "Moon axe",
        as: 368
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
        name: "Disarm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: 235,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: (244..263),
    pal_td: nil,
    ran_td: nil,
    sor_td: (273..294),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: (251..264),
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur horn",
    other: "Tiny golden seed"
  },
  messaging: {
    description: [
      "The minotaur warrior has the head of a bull while his muscular body is humanoid with thick arms and broad shoulders. Wearing a mish-mash of leather and chain armor, the fierce minotaur stomps about with hoofed feet brandishing its longsword at every possible foe."
    ],
    arrival: [],
    flee: [],
    death: [],
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
