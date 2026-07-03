{
  schema_version: 3,
  name: "black boar",
  noun: "",
  url: "https://gswiki.play.net/black_boar",
  picture: "",
  level: 14,
  family: "Suine",
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
  max_hp: 130,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Neartofar Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 171
      },
      {
        name: "Charge (attack)",
        as: 181
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: 82,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 42,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: 48,
    sor_td: 42,
    wiz_td: nil,
    mje_td: nil,
    mne_td: (36..42),
    mjs_td: nil,
    mns_td: 42,
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
    skin: "a black boar hide",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The black boar snorts and snuffles at the ground, peering around with his close-set, bloodshot eyes in hopes of finding a target for his anger and aggression.  Any who get in his way will most likely rapidly regret having done so.  His body is covered with coarse, black hair, and yellowed tusks protrude from each side of his gaping mouth.  Larger than most men, he is a good six feet long from dripping snout to curly tail and weighs more than a quarter ton.  When in motion, the black boar moves with a surprising speed and dexterity for a beast his size.  It is not unusual to find oneself snacked by this beast if not properly prepared.</pre>"
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
