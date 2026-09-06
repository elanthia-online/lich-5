{
  schema_version: 3,
  name: "imposing elk",
  noun: "elk",
  url: "https://gswiki.play.net/imposing_elk",
  picture: "",
  level: nil,
  family: "Deer",
  type: "Quadruped",
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
  otherclass: [],
  bcs: true,
  max_hp: 122,
  speed: 9,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Black Weald",
      uids: [7130001..7130018]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Antlers",
        as: 139
      },
      {
        name: "Charge",
        as: 148
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
    asg: nil,
    immunities: [],
    melee: (93..138),
    ranged: (90..93),
    bolt: (90..93),
    udf: (103..141),
    bar_td: nil,
    cle_td: (39..45),
    emp_td: (17..47),
    pal_td: (36..45),
    ran_td: (39..45),
    sor_td: (36..45),
    wiz_td: nil,
    mje_td: (33..39),
    mne_td: (33..39),
    mjs_td: (39..45),
    mns_td: (39..45),
    mnm_td: (39..45),
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
    gems: nil,
    boxes: nil,
    skin: "antlers",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ""
    ],
    arrival: [
      "An imposing elk trots in!"
    ],
    flee: [
      "An imposing elk trots {direction}.",
      "An imposing elk trots {direction}, snorting to announce {pronoun} arrival!",
      "An imposing elk snorts as {pronoun} slowly backs away."
    ],
    death: [
      "The imposing elk collapses to the ground, emits a final sigh, and dies.",
      "The imposing elk silently lets out a final agonized sigh and dies.",
      "The imposing elk lets out a final agonized sigh and dies.",
      "The imposing elk collapses to the ground, emits a final silent sigh, and dies."
    ],
    decay: [
      "An imposing elk decays into a pile of fur and bone."
    ],
    search: [
      "An imposing elk sniffs the air anxiously.",
      "An imposing elk glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "An imposing elk charges at you!",
        "An imposing elk tries to impale you with {pronoun} antlers!"
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
