{
  schema_version: 3,
  name: "greater burrow orc",
  noun: "",
  url: "https://gswiki.play.net/greater_burrow_orc",
  picture: "",
  level: 8,
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
  max_hp: 110,
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
        as: 128
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
    asg: "8",
    immunities: [],
    melee: (53..119),
    ranged: nil,
    bolt: 45,
    udf: 110,
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: nil,
    ran_td: nil,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
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
      "<pre{{log2|margin-right=26em}}>The burrow orc would stand roughly six feet high, were he not stooped over.  He is thinner and more gaunt than the land-roaming orcs, with sickly white skin and no hair on his smelly frame.  He seems more interested in stuffing himself and protecting his burrow than anything else.</pre>"
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
