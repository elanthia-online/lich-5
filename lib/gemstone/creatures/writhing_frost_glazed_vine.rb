{
  schema_version: 3,
  name: "writhing frost-glazed vine",
  noun: "vine",
  url: "https://gswiki.play.net/writhing_frost-glazed_vine",
  picture: "",
  level: 40,
  family: "Plant",
  type: "Plantlife",
  undead: true,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 388,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124037..4124049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Vine fling"
      },
      {
        name: "Stinger",
        as: 217
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (79..238),
    ranged: (96..130),
    bolt: (96..130),
    udf: (214..281),
    bar_td: nil,
    cle_td: (162..168),
    emp_td: (162..171),
    pal_td: (137..143),
    ran_td: (140..149),
    sor_td: (170..176),
    wiz_td: nil,
    mje_td: 172,
    mne_td: 172,
    mjs_td: (162..171),
    mns_td: (162..171),
    mnm_td: (120..129),
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "thorn-ridden appendage",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This \"little\" vine seems to be a bit on the feeling poorly side but if it catches you, likely you'll feel pretty bad too."
    ],
    arrival: [
      "A writhing frost-glazed vine slithers in grasping and twisting as it arrives."
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A writhing frost-glazed vine stabs at you with {pronoun} stinger!",
        "A writhing frost-glazed vine flings a length of vine towards you, but with a flash of incredible reflexes, you skip out of the way and the vine, trailing the rest of {pronoun} body, lands sprawling on the ground.",
        "A writhing frost-glazed vine stabs at {target} with {pronoun} stinger!",
        "A writhing frost-glazed vine writhes around in a full circle before pointing a thin appendage at you!"
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
