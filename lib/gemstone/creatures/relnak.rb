{
  schema_version: 3,
  name: "relnak",
  noun: "",
  url: "https://gswiki.play.net/relnak",
  picture: "",
  level: 3,
  family: "Reptilian",
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
  max_hp: 44,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Landing",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 61
      },
      {
        name: "Charge (attack)",
        as: 71
      },
      {
        name: "Stomp",
        as: 61
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
    melee: 81,
    ranged: 72,
    bolt: (27..77),
    udf: 46,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: nil,
    mns_td: 9,
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
    skin: "a relnak sail",
    other: nil
  },
  messaging: {
    description: [
      "The relnak is a low-slung, wide-bodied reptile of the chameleon family. Only a few feet long, it is deceptively fast despite its girth. Its skin is scaly, rough, and a uniform charcoal grey, except for the flaring, spiny sail that stands erect on its back. Extending from its thick neck to nearly the tip of its flicking tail, the sail's charcoal grey is punctuated by evenly spaced iridescent blue spines which glow brightly when the relnak is agitated."
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
