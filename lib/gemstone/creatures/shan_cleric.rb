{
  schema_version: 3,
  name: "shan cleric",
  noun: "",
  url: "https://gswiki.play.net/shan_cleric",
  picture: "",
  level: 42,
  family: "Shan",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: 212
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 209
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: 280,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (116..157),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 171,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 182,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Prayer (313)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Tiny golden seed"
  },
  messaging: {
    description: [
      "The shan cleric stands in a half-crouch, her long, knotty legs giving her that lanky, dangerous look of a wolf. Walking upright, the body covered with mottled grey fur and her long arms conclude in large, clawed hands with semi-opposable thumbs. The shan cleric's dog-like visage is fierce, with slavering jaws and eyes that glow like something out of a bad dream."
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
