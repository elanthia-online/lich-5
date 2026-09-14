{
  schema_version: 3,
  name: "barbed cavern urchin",
  noun: "urchin",
  url: "https://gswiki.play.net/barbed_cavern_urchin",
  picture: "",
  level: 17,
  family: "Urchin",
  type: "Globoid",
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
  max_hp: 154,
  speed: 11,
  height: 1,
  size: "tiny",
  areas: [
    {
      name: "Hornwort Cavern",
      uids: [7131001..7131018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Barbed spines",
        as: 176
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Spine Barrage"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (68..123),
    ranged: (59..89),
    bolt: (59..89),
    udf: (105..152),
    bar_td: nil,
    cle_td: (48..57),
    emp_td: (51..59),
    pal_td: (45..54),
    ran_td: (51..57),
    sor_td: (45..54),
    wiz_td: nil,
    mje_td: 57,
    mne_td: 57,
    mjs_td: (48..60),
    mns_td: (48..60),
    mnm_td: (51..57),
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
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [],
    flee: [],
    death: [],
    decay: [
      "Spines litter the ground as the cavern urchin crumbles into a pile of splinters and skin.",
      "A barbed cavern urchin simply withers away, bits of grayish dust scattered about in its wake."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A barbed cavern urchin clatters {pronoun} spines together in a feeble attempt to shake off the stun."
    ],
    attacks: {
      attack: [
        "A cavern urchin thrusts {pronoun} barbed spines at you!",
        "A barbed cavern urchin thrusts {pronoun} barbed spines at you!",
        "A barbed cavern urchin launches a barrage of spines, the barbs exploding outward at you!"
      ]
    },
    info: {
      general: [
        "Sibling of the spiked cavern urchin (also level 17, different zone)."
      ],
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
