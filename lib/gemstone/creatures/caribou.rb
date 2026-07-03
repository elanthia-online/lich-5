{
  schema_version: 3,
  name: "caribou",
  noun: "",
  url: "https://gswiki.play.net/caribou",
  picture: "",
  level: 32,
  family: "Deer",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 370,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Dark Caves",
      rooms: []
    },
    {
      name: "Northern Mountains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 238
      },
      {
        name: "Kick",
        as: 232
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
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 96,
    cle_td: nil,
    emp_td: (88..96),
    pal_td: nil,
    ran_td: nil,
    sor_td: (95..104),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 100,
    mjs_td: nil,
    mns_td: nil,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a pair of caribou antlers",
    other: nil
  },
  messaging: {
    description: [
      "A hoofed herbivore of the northern snowfields, the caribou is very similar to a large deer with a bad attitude. The caribou uses her large rack of antlers to eagerly impale anything that would encroach upon her territory. Light brown hide affords the caribou some camouflage against the more barren slopes, but the caribou relies on her defenses and running in herds to handle most predators."
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
