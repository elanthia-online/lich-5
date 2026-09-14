{
  schema_version: 3,
  name: "tawny brindlecat",
  noun: "brindlecat",
  url: "https://gswiki.play.net/tawny_brindlecat",
  picture: "",
  level: 13,
  family: "Feline",
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
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 123,
  speed: 6,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13034101..13034118, 13034201..13034221, 13034301..13034309]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (147..150)
      },
      {
        name: "Claw",
        as: (136..162)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      },
      {
        name: "Leap"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (82..151),
    ranged: (52..104),
    bolt: (52..104),
    udf: (90..166),
    bar_td: 39,
    cle_td: (39..45),
    emp_td: (35..43),
    pal_td: (30..39),
    ran_td: (39..42),
    sor_td: (39..45),
    wiz_td: 39,
    mje_td: (39..45),
    mne_td: (39..45),
    mjs_td: (39..66),
    mns_td: (39..66),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a tawny brindlecat hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The tawny brindlecat is a large, tawny brown animal of the cat family with a slender body and long tail. Larger than her cougar and puma cousins, her sleek build disguises her power. Both claws and jaws are to be feared, as the tawny brindlecat strikes quickly with each. Prized for her soft pelt, this feline is a proud and fierce hunter of the great eastern plains."
    ],
    arrival: [
      "A tawny brindlecat stalks in!",
      "A tawny brindlecat pounces to the ground in front of you!"
    ],
    flee: [
      "A tawny brindlecat bounds {direction}."
    ],
    death: [
      "The tawny brindlecat's tail twitches feebly as {pronoun} dies."
    ],
    decay: [
      "A tawny brindlecat decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A tawny brindlecat pounces on you, knocking you painfully to the ground!"
      ],
      bite: [
        "A tawny brindlecat tries to bite you!"
      ],
      claw: [
        "A tawny brindlecat claws at you!"
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
