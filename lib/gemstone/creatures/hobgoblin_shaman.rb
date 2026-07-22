{
  schema_version: 3,
  name: "hobgoblin shaman",
  noun: "",
  url: "https://gswiki.play.net/hobgoblin_shaman",
  picture: "",
  level: 7,
  family: "Goblin",
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
  max_hp: 80,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Leather whip",
        as: 111
      },
      {
        name: "Mace",
        as: 111
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 89
      },
      {
        name: "Minor Water (903)",
        as: 89
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: 24,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 24,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 20,
    wiz_td: nil,
    mje_td: 20,
    mne_td: 20,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Defense (103)",
      "Spirit Shield (202)",
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a shaman ear",
    other: nil
  },
  messaging: {
    description: [
      "The shaman has a surprisingly intelligent look for a hobgoblin shaman, though he is no less primitive and vicious than his tribesmen. His voice seems to be constantly uttering the harsh, guttural prayers that appease his barbaric deity. The fervor in the shaman's heart is clear from the frenzied gleam in his eyes."
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
