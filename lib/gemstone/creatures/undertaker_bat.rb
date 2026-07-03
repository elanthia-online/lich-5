{
  schema_version: 3,
  name: "undertaker bat",
  noun: "",
  url: "https://gswiki.play.net/undertaker_bat",
  picture: "",
  level: 36,
  family: "Bat",
  type: "Avian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Troll Burial Grounds",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 242
      },
      {
        name: "Claw",
        as: 182
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
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: 186,
    bolt: 166,
    udf: nil,
    bar_td: (113..122),
    cle_td: 120,
    emp_td: nil,
    pal_td: 108,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 147,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a bat wing",
    other: nil
  },
  messaging: {
    description: [
      "A rodent-like creature with a small head and distinct ears, its head covered with a fine textured short fur. The undertaker bat's leathery wings outstretch to three times its body length, with its skeletal features visable through its black skin. Small fangs protrude beyond its closed mouth."
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
