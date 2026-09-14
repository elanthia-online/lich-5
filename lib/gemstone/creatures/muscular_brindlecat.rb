{
  schema_version: 3,
  name: "muscular brindlecat",
  noun: "brindlecat",
  url: "https://gswiki.play.net/muscular_brindlecat",
  picture: "",
  level: nil,
  family: "Feline",
  type: "Quadruped",
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
  otherclass: [],
  bcs: true,
  max_hp: 158,
  speed: 6,
  height: 3,
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
        name: "Bite",
        as: 142
      },
      {
        name: "Claw",
        as: 119
      },
      {
        name: "Unknown",
        as: 137
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Leap"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (92..130),
    ranged: (-53..100),
    bolt: (-53..100),
    udf: (59..166),
    bar_td: nil,
    cle_td: (36..48),
    emp_td: (17..47),
    pal_td: (36..45),
    ran_td: (39..45),
    sor_td: (36..45),
    wiz_td: nil,
    mje_td: 45,
    mne_td: 45,
    mjs_td: (36..45),
    mns_td: (36..45),
    mnm_td: (36..39),
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
    skin: "tawny brindlecat hide.",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The muscular brindlecat is a large, tawny brown animal of the cat family with a slender body and long tail. Larger than her cougar and puma cousins, her sleek build disguises her power. Both claws and jaws are to be feared, as the muscular brindlecat strikes quickly with each. Prized for her soft pelt, this feline is a proud and fierce hunter of the great eastern plains."
    ],
    arrival: [
      "A muscular brindlecat stalks in!",
      "A muscular brindlecat pounces to the ground in front of you!"
    ],
    flee: [
      "A muscular brindlecat bounds {direction}."
    ],
    death: [
      "The muscular brindlecat's tail twitches feebly as {pronoun} dies."
    ],
    decay: [
      "A muscular brindlecat decays into a compost of fangs, fur and claws."
    ],
    search: [
      "A muscular brindlecat twitches {pronoun} whiskers while sniffing the air."
    ],
    spell_prep: [
      "A muscular brindlecat hisses loudly!"
    ],
    attacks: {
      attack: [
        "A muscular brindlecat leaps towards {target}, but misses and sprawls to the ground!"
      ],
      claw: [
        "A muscular brindlecat claws at you!"
      ],
      bite: [
        "A muscular brindlecat tries to bite you!"
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
