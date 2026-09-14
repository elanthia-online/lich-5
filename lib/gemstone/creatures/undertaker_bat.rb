{
  schema_version: 3,
  name: "undertaker bat",
  noun: "bat",
  url: "https://gswiki.play.net/undertaker_bat",
  picture: "",
  level: 36,
  family: "Bat",
  type: "Avian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 258,
  speed: nil,
  height: nil,
  size: "small",
  areas: [
    {
      name: "Troll Burial Grounds",
      uids: [13011009..13011035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (217..242)
      },
      {
        name: "Claw",
        as: (182..226)
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
    melee: (199..237),
    ranged: (142..208),
    bolt: (142..208),
    udf: (201..230),
    bar_td: (113..122),
    cle_td: (120..134),
    emp_td: (126..135),
    pal_td: (105..108),
    ran_td: (99..108),
    sor_td: (132..138),
    wiz_td: nil,
    mje_td: (133..147),
    mne_td: (133..147),
    mjs_td: 126,
    mns_td: 126,
    mnm_td: (108..114),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a bat wing",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "An undertaker bat rakes at you with a bony claw!"
      ],
      bite: [
        "An undertaker bat tries to bite you!"
      ],
      claw: [
        "An undertaker bat rakes at you with a bony claw!"
      ]
    },
    stand: [
      "An undertaker bat struggles to {pronoun} feet."
    ],
    description: [
      "A rodent-like creature with a small head and distinct ears, its head covered with a fine textured short fur. The undertaker bat's leathery wings outstretch to three times its body length, with its skeletal features visable through its black skin. Small fangs protrude beyond its closed mouth."
    ],
    arrival: [],
    flee: [
      "An undertaker bat wafts {direction}.",
      "An undertaker bat haphazardly glides {direction}."
    ],
    death: [
      "The undertaker bat twitches violently, then dies.",
      "The undertaker bat flaps its wings in a last ditch effort to ascend from the ground, but fails and finally lies still.",
      "As the strength drains out of the undertaker bat's wings, it falls to the ground in a motionless heap."
    ],
    decay: [
      "The undertaker bat decays into a tuft of matted hair and leathery wings."
    ],
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
