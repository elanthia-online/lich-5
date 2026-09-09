{
  schema_version: 3,
  name: "shan shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/shan_shaman",
  picture: "",
  level: 64,
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
  max_hp: 238,
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
    melee: (378..498),
    ranged: (257..458),
    bolt: (257..458),
    udf: (341..558),
    bar_td: nil,
    cle_td: (313..323),
    emp_td: (310..320),
    pal_td: (277..287),
    ran_td: (275..287),
    sor_td: (310..320),
    wiz_td: nil,
    mje_td: (317..322),
    mne_td: (317..322),
    mjs_td: (311..320),
    mns_td: (311..320),
    mnm_td: (219..228),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "an enruned parma",
    "an ivory-hilted khopesh",
    "some bone-adorned leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "A shan shaman wanders in chanting an orison!"
    ],
    flee: [
      "A shan shaman pads {direction}."
    ],
    death: [
      "The shan shaman yips in pain as {pronoun} falls to the ground motionless.",
      "The shan shaman howls out one last time and dies.",
      "The shan shaman shudders and falls to the ground motionless.",
      "A shan shaman's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shan shaman swings an ivory-hilted khopesh at you!",
        "A shan shaman waves a hand dismissively at you!"
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
