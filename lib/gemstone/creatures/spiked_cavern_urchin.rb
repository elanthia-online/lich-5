{
  schema_version: 3,
  name: "spiked cavern urchin",
  noun: "urchin",
  url: "https://gswiki.play.net/spiked_cavern_urchin",
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
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 160,
  speed: 11,
  height: 1,
  size: "tiny",
  areas: [
    {
      name: "Thurfel's Island",
      uids: [7532001..7532033]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: "(barbed spines) 176"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Barbed spines"
      },
      {
        name: "Spine Barrage"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (62..100),
    ranged: (62..80),
    bolt: (62..80),
    udf: (105..139),
    bar_td: 51,
    cle_td: (51..57),
    emp_td: (51..59),
    pal_td: (45..54),
    ran_td: (45..54),
    sor_td: (48..57),
    wiz_td: nil,
    mje_td: (51..54),
    mne_td: (51..54),
    mjs_td: (48..57),
    mns_td: (48..57),
    mnm_td: (51..54),
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a long fiery red spine",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Long barbed spines erupt outward from the cavern urchin, almost completely covering its body. The spear-like growths form a formidable defense, and also pose a lethal threat to anything that might find itself close enough to become impaled upon the spiked ends."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [
      "Spines litter the ground as the cavern urchin crumbles into a pile of splinters and skin.",
      "A spiked cavern urchin simply withers away, bits of grayish dust scattered about in its wake."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A spiked cavern urchin clatters {pronoun} spines together in a feeble attempt to shake off the stun."
    ],
    attacks: {
      attack: [
        "A spiked cavern urchin thrusts {pronoun} barbed spines at you!",
        "A spiked cavern urchin launches a barrage of spines, the barbs exploding outward at you!"
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
