{
  schema_version: 3,
  name: "silverback orc",
  noun: "orc",
  url: "https://gswiki.play.net/silverback_orc",
  picture: "",
  level: 14,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 170,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "High Plains",
      uids: [4129002..4129021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: (158..163)
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
    asg: "9",
    immunities: [],
    melee: (109..192),
    ranged: (83..109),
    bolt: (83..109),
    udf: (108..189),
    bar_td: 48,
    cle_td: (39..42),
    emp_td: (34..42),
    pal_td: (36..39),
    ran_td: 42,
    sor_td: 42,
    wiz_td: nil,
    mje_td: (42..48),
    mne_td: (42..48),
    mjs_td: (42..45),
    mns_td: (42..45),
    mnm_td: (36..42),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a falchion",
    "a leather breastplate",
    "a silver falchion"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a silverback orc knuckle",
    other: "Alchemy common",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Silver-flecked eyes match the garish silver stripe down the silverback orc's back. It stands a hearty six feet tall, with pale white skin. Were it not for the flecks of blood and bits of tattered flesh sticking to its skin, it mayhaps be attractive. Or perhaps not."
    ],
    arrival: [
      "A silverback orc barrels in, {pronoun} face contorted in anger."
    ],
    flee: [
      "A silverback orc runs {direction}."
    ],
    death: [
      "A silverback orc curls up in the snow and dies.",
      "A silverback orc curls up and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A silverback orc gives a cold shudder as {pronoun} tries to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A silverback orc swings {weapon} at you!",
        "A silverback orc leaps from behind a snow drift!"
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
