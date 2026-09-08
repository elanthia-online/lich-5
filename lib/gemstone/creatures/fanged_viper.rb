{
  schema_version: 3,
  name: "fanged viper",
  noun: "viper",
  url: "https://gswiki.play.net/fanged_viper",
  picture: "",
  level: 4,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 51,
  speed: 8,
  height: 1,
  size: "small",
  areas: [
    {
      name: "The Toadwort",
      uids: [14007012..14007041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 68
      },
      {
        name: "Unknown",
        as: 68
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
    asg: "5N",
    immunities: [],
    melee: (31..37),
    ranged: 33,
    bolt: 33,
    udf: 51,
    bar_td: 12,
    cle_td: 12,
    emp_td: 12,
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: nil,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
    mnm_td: 12,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a viper skin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The fanged viper slithers quickly through the landscape, searching for small prey upon which to feed. Its massive venomous fangs hidden by small flaps of skin, this docile snake until disturbed, appears non-threatening. Once it is disturbed and its ire is aroused, the small flaps pull back revealing the true monster it is. Death rapidly awaits any who doubt its abilities."
    ],
    arrival: [],
    flee: [
      "A fanged viper slithers {direction}."
    ],
    death: [],
    decay: [
      "A fanged viper decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A fanged viper tries to bite you!"
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
