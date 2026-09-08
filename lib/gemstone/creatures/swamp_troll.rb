{
  schema_version: 3,
  name: "swamp troll",
  noun: "troll",
  url: "https://gswiki.play.net/swamp_troll",
  picture: "",
  level: 14,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 170,
  speed: 14,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Central Caravansary",
      uids: [4748201..4748215]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: (155..173)
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
    asg: "11N",
    immunities: [],
    melee: (71..107),
    ranged: (64..93),
    bolt: (64..93),
    udf: (102..104),
    bar_td: 49,
    cle_td: 57,
    emp_td: 57,
    pal_td: (54..57),
    ran_td: 57,
    sor_td: 53,
    wiz_td: nil,
    mje_td: 49,
    mne_td: 49,
    mjs_td: 57,
    mns_td: 57,
    mnm_td: (42..49),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a cudgel"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a swamp troll scalp",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the swamp troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.\n\nThe swamp troll is large in size and about nine feet high in its current state."
    ],
    arrival: [
      "A swamp troll just arrived!"
    ],
    flee: [
      "A swamp troll heads {direction}."
    ],
    death: [
      "The swamp troll falls to the ground and dies.",
      "The swamp troll screams one last time and dies."
    ],
    decay: [
      "A swamp troll decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A swamp troll swings {weapon} at you!"
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
