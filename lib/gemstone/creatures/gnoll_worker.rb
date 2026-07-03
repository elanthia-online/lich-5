{
  schema_version: 3,
  name: "gnoll worker",
  noun: "",
  url: "https://gswiki.play.net/gnoll_worker",
  picture: "",
  level: 10,
  family: "Gnoll",
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
  max_hp: 130,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Zeltoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hatchet",
        as: 125
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
    asg: "6",
    immunities: [],
    melee: 159,
    ranged: nil,
    bolt: (58..95),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 30,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Hides when attacked"
    ]
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
    skin: nil,
    other: "Yes"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The gnoll worker is about three feet tall and vaguely man-like.  Gnolls in general have a dwarven or gnomish appearance, but are markedly different in a way that can't quite be pin-pointed.  This particular gnoll is part of the working class with well-muscled arms and callused hands.  There is little doubt that the gnoll would be a formidable opponent if the need should arise, or if backed into a corner.</pre>"
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
