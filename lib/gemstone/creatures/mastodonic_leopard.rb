{
  schema_version: 3,
  name: "mastodonic leopard",
  noun: "leopard",
  url: "https://gswiki.play.net/mastodonic_leopard",
  picture: "",
  level: 44,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Gyldemar Forest",
      uids: [13028001..13028037, 13028084..13028091]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (242..269)
      },
      {
        name: "Claw",
        as: 279
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Caterwaul"
      },
      {
        name: "Leap"
      }
    ],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "10N",
    immunities: [],
    melee: (168..252),
    ranged: (201..211),
    bolt: (201..205),
    udf: (273..313),
    bar_td: 135,
    cle_td: (140..149),
    emp_td: (148..157),
    pal_td: (129..138),
    ran_td: (126..135),
    sor_td: (157..163),
    wiz_td: nil,
    mje_td: (158..166),
    mne_td: (158..166),
    mjs_td: (139..148),
    mns_td: (139..148),
    mnm_td: (132..138),
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
    skin: "a spotted leopard pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mastodonic leopard has a long, narrow body, relatively short muscular legs and large broad paws. His large, broad tail is used for balancing himself in the trees. Two alert yellow eyes gaze over his broad snout, capped on the leopard's narrow head by his tufted ears. Most striking are his markings: six large, narrow, brown blotches, edged in black, with pale areas separating the blotches on his sides. Along his back, the leopard has a series of large open-centered spots, and his underside is solidly pale. The mastodonic leopard's square jaw and extra long canine teeth, characteristic of the northern sabre-toothed tiger, are ideal for shredding meat."
    ],
    arrival: [
      "A mastodonic leopard prowls in!",
      "A mastodonic leopard crouches as {pronoun} stalks into view!",
      "A stalwart mastodonic leopard prowls in!",
      "A flashy mastodonic leopard prowls in!"
    ],
    flee: [
      "A mastodonic leopard prowls {direction}.",
      "A stalwart mastodonic leopard prowls {direction}.",
      "A dazzling mastodonic leopard prowls {direction}.",
      "A mastodonic leopard slowly backs away."
    ],
    death: [
      "The mastodonic leopard lets out a final caterwaul and dies.",
      "The mastodonic leopard crumples to the ground and dies."
    ],
    decay: [
      "A mastodonic leopard decays into a compost of fangs, fur and claws.",
      "A robust mastodonic leopard decays into a compost of fangs, fur and claws.",
      "A stalwart mastodonic leopard decays into a compost of fangs, fur and claws.",
      "A dazzling mastodonic leopard decays into a compost of fangs, fur and claws.",
      "A flashy mastodonic leopard decays into a compost of fangs, fur and claws.",
      "A glittering mastodonic leopard decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mastodonic leopard leaps from a tree branch overhead!",
        "A mastodonic leopard leaps from a branch overhead!"
      ],
      bite: [
        "A mastodonic leopard tries to bite you!"
      ],
      claw: [
        "A mastodonic leopard claws at you!"
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
