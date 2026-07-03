{
  schema_version: 3,
  name: "leaper",
  noun: "",
  url: "https://gswiki.play.net/leaper",
  picture: "",
  level: 6,
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
  max_hp: 69,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 94
      },
      {
        name: "Claw",
        as: 94
      },
      {
        name: "Stomp",
        as: 94
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
    melee: (9..29),
    ranged: nil,
    bolt: 9,
    udf: (54..77),
    bar_td: 18,
    cle_td: nil,
    emp_td: 16,
    pal_td: nil,
    ran_td: 18,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 18,
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
    skin: "a leaper hide",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The leaper appears a bizarre cross between a wolf and a frog.  Perhaps six feet from snout to rump, covered with slick, hairless skin in a dark green, it lacks all trace of fur but has a set of fangs worthy of any wolf that ever strode the land.  Extra long front legs tipped with raking claws give it the bounding gait that has earned its name.</pre>\n\nThe leaper is medium in size and about three feet high."
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
