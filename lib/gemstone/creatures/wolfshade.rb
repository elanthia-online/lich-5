{
  schema_version: 3,
  name: "wolfshade",
  noun: "",
  url: "https://gswiki.play.net/wolfshade",
  picture: "",
  level: 15,
  family: "Canine",
  type: "Quadruped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Plains of Bone",
      rooms: []
    },
    {
      name: "Sentoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 133
      },
      {
        name: "Claw",
        as: 133
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
    asg: "1N",
    immunities: [],
    melee: (85..95),
    ranged: 68,
    bolt: 68,
    udf: 110,
    bar_td: 45,
    cle_td: 45,
    emp_td: 45,
    pal_td: 45,
    ran_td: 45,
    sor_td: 45,
    wiz_td: 45,
    mje_td: 45,
    mne_td: 45,
    mjs_td: 45,
    mns_td: 45,
    mnm_td: 45,
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "The wolfshade is the animated spirit of a powerful northern grey wolf, one of the larger members of the wolf species. Even in death, the wolfshade still possesses the instincts and abilities of its living form, including keen hearing, smell, sight, and extremely quick reflexes. Dark grey with bloodshot eyes, the wolfshade is driven onward by a hunger for living flesh that it can never hope to satisfy."
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
