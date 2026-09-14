{
  schema_version: 3,
  name: "Agresh troll chieftain",
  noun: "chieftain",
  url: "https://gswiki.play.net/agresh_troll_chieftain",
  picture: "",
  level: 20,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: 14,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Grasslands",
      uids: [14012100..14012120, 14012150..14012165]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 247
      },
      {
        name: "Military pick",
        as: 227
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "+40 AS boost"
      },
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (75..195),
    ranged: (76..113),
    bolt: (76..113),
    udf: (126..133),
    bar_td: 67,
    cle_td: 75,
    emp_td: 75,
    pal_td: (72..75),
    ran_td: 75,
    sor_td: 71,
    wiz_td: nil,
    mje_td: 67,
    mne_td: 67,
    mjs_td: 75,
    mns_td: 75,
    mnm_td: (60..67),
    defensive_spells: [
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
    "a flail",
    "a leather helm",
    "a military pick",
    "a visored helm",
    "an augmented breastplate",
    "some brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence shardGlimmering blue mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The troll chieftain splatters its surroundings with flecks of spittle as it lifts its head and snarls. Crudely drawn symbols painted with ash on its face do little to improve its gruesome visage as it scrunches its face into an expression of rage. Tufts of golden hair on its otherwise barren body make it look that much more ugly."
    ],
    arrival: [
      "An Agresh troll chieftain just arrived!",
      "An Agresh troll chieftain charges in, {pronoun} eyes gleaming with hate!"
    ],
    flee: [
      "An Agresh troll chieftain limps {direction}.",
      "An Agresh troll chieftain runs {direction}."
    ],
    death: [
      "The troll chieftain bellows in rage one last time and dies."
    ],
    decay: [
      "An Agresh troll chieftain decays into compost."
    ],
    search: [
      "An Agresh troll chieftain sniffs the air cautiously."
    ],
    spell_prep: [
      "An Agresh troll chieftain mutters, \"Srlarloror'rt srar 'mrosrdnragh srar 'r'rar s'r'vr'r'rawrd!\""
    ],
    attacks: {
      attack: [
        "An Agresh troll chieftain swings {weapon} at you!",
        "An Agresh troll chieftain charges in, {pronoun} eyes gleaming with hate!"
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
