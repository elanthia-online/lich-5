{
  schema_version: 3,
  name: "striped warcat",
  noun: "",
  url: "https://gswiki.play.net/striped_warcat",
  picture: "",
  level: 20,
  family: "Feline",
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
  max_hp: 180,
  speed: "~8 sec",
  height: nil,
  size: "",
  areas: [
    {
      name: "Smokey Caverns",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 195
      },
      {
        name: "Bite",
        as: 193
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Leap (knock down)"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "10N",
    immunities: [],
    melee: "91 to 108",
    ranged: nil,
    bolt: "74 to 93",
    udf: nil,
    bar_td: 60,
    cle_td: 60,
    emp_td: 60,
    pal_td: nil,
    ran_td: nil,
    sor_td: 61,
    wiz_td: 63,
    mje_td: 63,
    mne_td: 63,
    mjs_td: 60,
    mns_td: 60,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a warcat whisker",
    other: "no"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The striped warcat is a large ornery cat.  It is fairly large, standing roughly a head over a halfling.  Wide, tapering grey stripes run down the side of its black fur.  Its amber eyes gleam hypnotically as it stares back in your direction.</pre>"
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
