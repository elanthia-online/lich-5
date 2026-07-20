{
  schema_version: 3,
  name: "greater construct",
  noun: "",
  url: "https://gswiki.play.net/greater_construct",
  picture: "",
  level: 96,
  family: "Golem",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 500,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Ta'Faendryl",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stomp",
        as: (435..443)
      },
      {
        name: "Arm",
        as: 449
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Crush"
      },
      {
        name: "Tandem Dispel"
      },
      {
        name: "Team Swat"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: nil,
    ranged: (299..344),
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: (366..387),
    emp_td: (358..379),
    pal_td: nil,
    ran_td: nil,
    sor_td: 398,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Antimagic aura"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "The white granite-like features of the greater construct hold no hints of the giant creature's intentions or motivations. Its alabaster skin made more of the hardest rock than any living tissue makes the construct a formidable opponent for any who dare to trifle with it. Massing more than ten giantmen, it is a mountain of rock when in motion and very little, man or animal can oppose its desired path of travel once it is in motion."
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
