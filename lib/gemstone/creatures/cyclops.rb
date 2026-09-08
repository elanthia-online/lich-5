{
  schema_version: 3,
  name: "cyclops",
  noun: "cyclops",
  url: "https://gswiki.play.net/cyclops",
  picture: "",
  level: 27,
  family: "Humanoid",
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
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 319,
  speed: 12,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Noman's Land",
      uids: [4600010..4600020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 238
      },
      {
        name: "Pound (attack)",
        as: 238
      },
      {
        name: "Stomp (attack)",
        as: 238
      },
      {
        name: "Splintered tree trunk",
        as: 187
      },
      {
        name: "Fist",
        as: 175
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
    asg: "11",
    immunities: [],
    melee: (179..265),
    ranged: (129..168),
    bolt: (129..168),
    udf: (216..264),
    bar_td: 84,
    cle_td: (78..84),
    emp_td: (81..89),
    pal_td: (75..84),
    ran_td: (78..84),
    sor_td: (75..84),
    wiz_td: 84,
    mje_td: (81..84),
    mne_td: (81..84),
    mjs_td: (75..84),
    mns_td: (75..84),
    mnm_td: (81..87),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a fetid urgh hide",
    "a splintered tree trunk"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a cyclops eye",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Towering twice the height of the tallest giantman, the cyclops myopically observes the surrounding terrain through its solitary eye. Aside from these features, the cyclops would appear as any other giantman and is often found wearing animal hides. Blessed with gargantuan strength, the cyclops can wield a 100 pound tree trunk with the same effort that an adventurer wields a dagger. The cyclops, however, is cursed with poor depth perception, limiting the effect of its attack. It is not a good practice to tease the cyclops by calling it 'One Eye.'"
    ],
    arrival: [
      "A cyclops just arrived!",
      "A cyclops just arrived."
    ],
    flee: [
      "A cyclops heads {direction}.",
      "A cyclops limps {direction}."
    ],
    death: [
      "The cyclops rolls over and dies.",
      "The cyclops falls to the ground and dies."
    ],
    decay: [
      "A cyclops decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A cyclops swings {weapon} at you!",
        "A cyclops pounds at you with {pronoun} fist!"
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
