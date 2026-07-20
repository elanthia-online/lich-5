{
  schema_version: 3,
  name: "stone mastiff",
  noun: "",
  url: "https://gswiki.play.net/stone_mastiff",
  picture: "",
  level: 62,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (335..345)
      },
      {
        name: "Claw",
        as: 332
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (147..279),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (206..227),
    cle_td: 236,
    emp_td: nil,
    pal_td: 201,
    ran_td: nil,
    sor_td: 247,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 260,
    mjs_td: nil,
    mns_td: 233,
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
    skin: "a stone heart",
    other: nil
  },
  messaging: {
    description: [
      "The stone mastiff is a huge grey dog that seems to be formed of living stone. The mastiff is rectangular in shape, and the length of the mastiff from forechest to rear is around five feet. Massive and heavy boned, with a powerful muscle structure, this stone mastiff presents a formidable foe."
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
