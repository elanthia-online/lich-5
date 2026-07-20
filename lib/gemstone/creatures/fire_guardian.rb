{
  schema_version: 3,
  name: "fire guardian",
  noun: "",
  url: "https://gswiki.play.net/fire_guardian",
  picture: "",
  level: 16,
  family: "Elemental",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Element-based"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glatoph",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 152
      },
      {
        name: "Ensnare (attack)",
        as: 152
      },
      {
        name: "Charge (attack)",
        as: 152
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 124
      },
      {
        name: "Major Fire (908)",
        as: 124
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
    melee: 51,
    ranged: 37,
    bolt: 48,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 48,
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: nil,
    mns_td: 48,
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
    other: "Essence of fire"
  },
  messaging: {
    description: [
      "A towering mass of flame and smoke formed into a caricature of a living being, the fire guardian is awesome to behold. The fumes of endless burning and the fierce heat serve this foul thing as well as any armor made by mortal; and the power of its flame has fused even the finest vultite shields to the hands of their wearers and turned mighty swords into dripping stubs of molten alloy."
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
