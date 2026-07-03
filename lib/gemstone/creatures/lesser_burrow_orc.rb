{
  schema_version: 3,
  name: "lesser burrow orc",
  noun: "",
  url: "https://gswiki.play.net/lesser_burrow_orc",
  picture: "",
  level: 7,
  family: "Orc",
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
  max_hp: 100,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Melgorehn's Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 127
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
    melee: (54..126),
    ranged: nil,
    bolt: 40,
    udf: 116,
    bar_td: nil,
    cle_td: nil,
    emp_td: 21,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
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
    skin: "an orc claw",
    other: nil
  },
  messaging: {
    description: [
      "The burrow orc would stand roughly six feet high, were she not stooped over. She is thinner and more gaunt than the land-roaming orcs, with sickly white skin and no hair on her smelly frame. She seems more interested in stuffing herself and protecting her burrow than anything else."
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
