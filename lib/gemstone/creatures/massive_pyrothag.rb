{
  schema_version: 3,
  name: "massive pyrothag",
  noun: "",
  url: "https://gswiki.play.net/massive_pyrothag",
  picture: "",
  level: 58,
  family: "Pyrothag",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical",
    "Element-based"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Lava Flows",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 302
      },
      {
        name: "Stomp (attack)",
        as: 253
      },
      {
        name: "Pound (attack)",
        as: 283
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
    asg: "12N",
    immunities: [],
    melee: (211..281),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "229; 238",
    wiz_td: nil,
    mje_td: nil,
    mne_td: "241; 244",
    mjs_td: nil,
    mns_td: "191; 219",
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
    skin: "a pyrothag hide",
    other: "glowing violet mote of essence"
  },
  messaging: {
    description: [
      "The pyrothag is a huge creature, towering over the tallest of giantmen. Scorched black by the heat of its environment, its thick skin protects it from blows and the hostile lava flows. The most striking thing aside from its size, is the lack of facial features. A smooth face matching its smooth black skin leaves one wondering how such a thing could have evolved."
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
