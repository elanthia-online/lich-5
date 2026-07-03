{
  schema_version: 3,
  name: "brown spinner",
  noun: "",
  url: "https://gswiki.play.net/brown_spinner",
  picture: "",
  level: 9,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 90,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (107..119)
      },
      {
        name: "Pincer (attack)",
        as: (95..107)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (79..151),
    ranged: nil,
    bolt: 60,
    udf: (78..160),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 27,
    mne_td: 27,
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
    coins: true,
    magic_items: false,
    gems: true,
    boxes: false,
    skin: "brown spinner leg",
    other: nil
  },
  messaging: {
    description: [
      "This servant of the huntress is both guardian and warrior for its mistress. Its brown coloring and smaller size makes it seem less dangerous than other, larger spiders. However, the fine brown hair on its body is probably used to seek out hidden spies, and its spinnaret to immobilize them."
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
