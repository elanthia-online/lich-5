{
  schema_version: 3,
  name: "cold guardian",
  noun: "",
  url: "https://gswiki.play.net/cold_guardian",
  picture: "",
  level: 34,
  family: "Elemental",
  type: "Elemental",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Frozen Battlefield",
      rooms: []
    },
    {
      name: "Glatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 240
      },
      {
        name: "Charge",
        as: 220
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 193
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: 170,
    ranged: nil,
    bolt: 163,
    udf: 205,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 123,
    wiz_td: nil,
    mje_td: 129,
    mne_td: 129,
    mjs_td: nil,
    mns_td: 117,
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
    other: "Alchemy components, Lockpicks"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A swirling column of ice that is somehow animate faces you.  A biting cold mist flows around it to chill you and to sink a numbing dampness deep into your bones.  Moisture condenses from the very air onto the guardian and pale frost collects on its surface only to grow heavy and break free with a cold, brittle sound that echoes like faint mocking laughter.</pre>"
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
