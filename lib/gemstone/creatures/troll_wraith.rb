{
  schema_version: 3,
  name: "troll wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/troll_wraith",
  picture: "",
  level: 35,
  family: "Troll",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: nil,
  max_hp: 400,
  speed: nil,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Troll Burial Grounds",
      uids: [13011001..13011035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (214..215)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Point",
        cs: 177
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (101..260),
    ranged: (113..147),
    bolt: (105..147),
    udf: (217..342),
    bar_td: (118..123),
    cle_td: (129..139),
    emp_td: (130..136),
    pal_td: (109..119),
    ran_td: (110..119),
    sor_td: (139..142),
    wiz_td: nil,
    mje_td: (143..148),
    mne_td: (143..148),
    mjs_td: (132..141),
    mns_td: (132..141),
    mnm_td: (119..128),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense III (414)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some blackened steel gauntlets"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing Violet Essence Dust",
      "glowing violet mote of essence"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A sickly, ebony mist encircles the troll wraith, obscuring the entire lower portion of the wraith, if there was one. Brilliant, platinum-hued orbs suspend in the air where the wraith's eyes once resided. The only true evidence of the wraith's former life are remnants of blackened steel gauntlets protecting the hands with only a few boney fingers being exposed."
    ],
    arrival: [],
    flee: [
      "A troll wraith drifts {direction}."
    ],
    death: [
      "A troll wraith slumps to the ground, lying completely motionless.  A last minute twitch causes the wraith's arm to spasm up into the air before falling limply back to {pronoun} side.",
      "A troll wraith falls to the ground, lying completely motionless. A last minute twitch causes the wraith's arm to spasm up into the air before falling limply back to {pronoun} side."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A troll wraith throws {pronoun} arms up to the heavens and wails, \"Tghgrrilarbr sirght 'rghudn' ri tr'srumor r'r'gnolor ghrumr wrogh?\""
      ],
      cast: [
        "A troll wraith points a boney finger at {target}!"
      ],
      claw: [
        "A troll wraith claws at you!"
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
