{
  schema_version: 3,
  name: "shan rogue",
  noun: "rogue",
  url: "https://gswiki.play.net/shan_rogue",
  picture: "",
  level: 66,
  family: "Shan",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 300,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Forgotten Vineyard",
      uids: [4225017..4225036]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
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
    melee: (271..436),
    ranged: (260..336),
    bolt: (260..336),
    udf: 323,
    bar_td: nil,
    cle_td: (236..245),
    emp_td: (232..241),
    pal_td: (183..186),
    ran_td: 210,
    sor_td: (254..260),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 244,
    mns_td: 244,
    mnm_td: (195..198),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bronze-edged targe",
    "a bruised left eye",
    "a bruised right eye",
    "a slender kris",
    "some faded brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [],
    flee: [
      "A shan rogue pads {direction}."
    ],
    death: [
      "The shan rogue yips in pain as {pronoun} falls to the ground motionless.",
      "The shan rogue howls out one last time and dies.",
      "A shan rogue's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shan rogue leaps from hiding to attack!",
        "A shan rogue swings a slender kris at you!",
        "A shan rogue springs upon you from behind and aims a blow to your head!"
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
