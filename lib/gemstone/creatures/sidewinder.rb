{
  schema_version: 3,
  name: "sidewinder",
  noun: "sidewinder",
  url: "https://gswiki.play.net/sidewinder",
  picture: "",
  level: 98,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Shadow of the Sanctum",
      uids: [4216141..4216141, 4216148..4216148]
    },
    {
      name: "unmapped",
      uids: [4216142..4216147]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 459
      },
      {
        name: "Strike",
        as: 469
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Strike"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 411,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Root",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a sidewinder scale",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The swiftly writhing coils and flared, triangular head tells one all they need to know about the sidewinder: it is fast, and it is deadly. Scales as white as ivory flakes proceed in a sinuous pattern down the sidewinder's back, the muscles beneath undulating from side to side to propel it forward."
    ],
    arrival: [
      "A white sidewinder slithers in, silent as a pale shadow."
    ],
    flee: [
      "A white sidewinder cuts a winding path across the floor as it slithers {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A sheen of venom glistening from {pronoun} needle-sharp fangs, a white sidewinder strikes at you!",
        "A sidewinder darts in for a quick strike at you!"
      ]
    },
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
