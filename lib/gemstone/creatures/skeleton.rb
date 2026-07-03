{
  schema_version: 3,
  name: "skeleton",
  noun: "",
  url: "https://gswiki.play.net/skeleton",
  picture: "",
  level: 1,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 40,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (21..31)
      },
      {
        name: "Dagger",
        as: (21..31)
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
    asg: "5",
    immunities: [],
    melee: 1,
    ranged: nil,
    bolt: "-1",
    udf: 33,
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    skin: "skeleton bone",
    other: nil
  },
  messaging: {
    description: [
      "The skeleton clatters noisily about as if lost in the world of the living. Bleached bones, barely connected by stiff, crystallized tendons, tell a story of flesh long rotted away. Cockroaches, maggots and other insect types, perhaps still feeding on the rotting remains of the brain of the skeleton, scuttle and slither liberally in and out of the cranial sockets."
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
