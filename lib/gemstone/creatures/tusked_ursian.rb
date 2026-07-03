{
  schema_version: 3,
  name: "tusked ursian",
  noun: "",
  url: "https://gswiki.play.net/tusked_ursian",
  picture: "",
  level: 37,
  family: "Bear",
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
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Gyldemar Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 260
      },
      {
        name: "Charge (attack)",
        as: 260
      },
      {
        name: "Bite",
        as: 260
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Charge"
      },
      {
        name: "Squeal"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 139,
    ranged: (124..127),
    bolt: nil,
    udf: nil,
    bar_td: 111,
    cle_td: 120,
    emp_td: nil,
    pal_td: nil,
    ran_td: 111,
    sor_td: 135,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 142,
    mjs_td: nil,
    mns_td: (120..129),
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
    skin: "an ursian tusk",
    other: "No"
  },
  messaging: {
    description: [
      "Standing nearly nine feet in height, the tusked ursian appears to be an unnatural union between a boar and a bear. Her yellow-tusked maw is lined with jagged fangs and beady eyes peer over a moist snout. Powerful limbs ending in black-nailed claws attest to the ferocity of this beast."
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
