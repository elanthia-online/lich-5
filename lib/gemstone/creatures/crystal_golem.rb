{
  schema_version: 3,
  name: "crystal golem",
  noun: "",
  url: "https://gswiki.play.net/crystal_golem",
  picture: "",
  level: 12,
  family: "Golem",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Mine Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 134
      },
      {
        name: "Pound",
        as: 134
      },
      {
        name: "Stomp",
        as: 144
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Foot stomp"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "14N",
    immunities: [],
    melee: 112,
    ranged: nil,
    bolt: 60,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (30..42),
    wiz_td: nil,
    mje_td: (30..42),
    mne_td: (30..42),
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "a crystal core"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Towering about three yards tall, a crystal golem's form is nothing short of massive.  Deeply set fires glimmer coldly from its eye sockets, throwing a myriad of colors throughout the large crystal spikes jutting sharply away from its thick crystalline skin.  As it moves, the rainbow color flickers through the facets of its body in a dizzying array of color.</pre>"
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
