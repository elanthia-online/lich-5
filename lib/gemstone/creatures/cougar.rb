{
  schema_version: 3,
  name: "cougar",
  noun: "cougar",
  url: "https://gswiki.play.net/cougar",
  picture: "",
  level: 22,
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
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 195,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4218101..4218121]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (196..203)
      },
      {
        name: "Claw",
        as: 208
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Kick"
      },
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
    melee: (139..239),
    ranged: (64..176),
    bolt: (64..176),
    udf: (147..195),
    bar_td: 66,
    cle_td: (60..80),
    emp_td: (66..85),
    pal_td: (62..72),
    ran_td: (63..69),
    sor_td: (63..72),
    wiz_td: nil,
    mje_td: (60..66),
    mne_td: (60..66),
    mjs_td: (146..155),
    mns_td: (146..155),
    mnm_td: (63..72),
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
    skin: "a cougar tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The cougar is a large, tawny brown animal of the cat family with a slender body and long tail. Her sleek build disguises her power. Both claws and jaws are to be feared, as the cougar strikes quickly with each. Prized for her soft pelt, this cat's hunting grounds have been severely diminished in recent years due to overhunting, though many of her breed can still be found in more remote areas and backwaters."
    ],
    arrival: [
      "A cougar scampers in, mewling in pain!",
      "A cougar scampers in!",
      "A deft cougar scampers in!",
      "An adroit cougar scampers in!",
      "A canny cougar scampers in!",
      "A keen cougar scampers in!",
      "A belligerent cougar scampers in!",
      "A luminous cougar scampers in!",
      "A dreary cougar scampers in!",
      "A glittering cougar scampers in!",
      "A cougar pounces to the ground in front of you!"
    ],
    flee: [
      "A cougar scampers {direction}.",
      "A cougar scampers {direction}, mewling in pain.",
      "A barbed cougar scampers {direction}.",
      "A deft cougar scampers {direction}.",
      "A robust cougar scampers {direction}.",
      "A keen cougar scampers {direction}.",
      "A combative cougar scampers {direction}.",
      "A stalwart cougar scampers {direction}.",
      "A canny cougar scampers {direction}.",
      "A shielded cougar scampers {direction}.",
      "A glittering cougar scampers {direction}."
    ],
    death: [
      "The cougar lets out a final caterwaul and dies.",
      "The cougar crumples to the ground and dies.",
      "The cougar twitches violently, then dies."
    ],
    decay: [
      "A cougar decays into a compost of fangs, fur and claws.",
      "A barbed cougar decays into a compost of fangs, fur and claws.",
      "A spiny cougar decays into a compost of fangs, fur and claws.",
      "An adroit cougar decays into a compost of fangs, fur and claws.",
      "A deft cougar decays into a compost of fangs, fur and claws.",
      "A stalwart cougar decays into a compost of fangs, fur and claws.",
      "A robust cougar decays into a compost of fangs, fur and claws.",
      "A shimmering cougar decays into a compost of fangs, fur and claws.",
      "A gleaming cougar decays into a compost of fangs, fur and claws.",
      "A keen cougar decays into a compost of fangs, fur and claws.",
      "A canny cougar decays into a compost of fangs, fur and claws.",
      "A belligerent cougar decays into a compost of fangs, fur and claws.",
      "A combative cougar decays into a compost of fangs, fur and claws.",
      "A lustrous cougar decays into a compost of fangs, fur and claws.",
      "A luminous cougar decays into a compost of fangs, fur and claws.",
      "A dreary cougar decays into a compost of fangs, fur and claws.",
      "A drab cougar decays into a compost of fangs, fur and claws.",
      "A shielded cougar decays into a compost of fangs, fur and claws.",
      "A glittering cougar decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A cougar claws at you!"
      ],
      bite: [
        "A cougar tries to bite you!"
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
