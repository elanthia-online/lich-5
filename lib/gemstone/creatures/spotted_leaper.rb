{
  schema_version: 3,
  name: "spotted leaper",
  noun: "",
  url: "https://gswiki.play.net/spotted_leaper",
  picture: "",
  level: 4,
  family: "Leaper",
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
  max_hp: 51,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Rambling Meadows",
      rooms: []
    },
    {
      name: "Shores of Lough Ne'Halin",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 76
      },
      {
        name: "Claw",
        as: 76
      },
      {
        name: "Stomp",
        as: 76
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
    asg: "5N",
    immunities: [],
    melee: (20..33),
    ranged: 17,
    bolt: 15,
    udf: nil,
    bar_td: 12,
    cle_td: nil,
    emp_td: 12,
    pal_td: nil,
    ran_td: 12,
    sor_td: 12,
    wiz_td: 12,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
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
    skin: "a spotted leaper pelt",
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The spotted leaper appears a bizarre cross between a wolf and a frog.  Perhaps six feet from snout to rump, covered with slick, hairless skin that is a dark green color with occasional pink splotches, it lacks all trace of fur but has a set of fangs worthy of any wolf that ever strode the land.  Extra long front legs tipped with raking claws give it the bounding gait that has earned it its name.</pre>"
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
