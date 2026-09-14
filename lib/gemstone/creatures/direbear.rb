{
  schema_version: 3,
  name: "direbear",
  noun: "direbear",
  url: "https://gswiki.play.net/direbear",
  picture: "",
  level: 65,
  family: "Bear",
  type: "Quadruped",
  undead: false,
  blood: nil,
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
  max_hp: 400,
  speed: nil,
  height: 4,
  size: "large",
  areas: [
    {
      name: "Red Forest",
      uids: [480216..480230, 17006216..17006230]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 349
      },
      {
        name: "Claw (attack)",
        as: (340..355)
      },
      {
        name: "Bite",
        as: (270..280)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Bertrandt's Bellow"
      },
      {
        name: "Gerrelle's Growl"
      },
      {
        name: "Red eyes (AS boost)"
      }
    ],
    maneuvers: [
      {
        name: "Bearhug"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (162..357),
    ranged: (158..283),
    bolt: (158..283),
    udf: (208..446),
    bar_td: (234..240),
    cle_td: 306,
    emp_td: 305,
    pal_td: (281..284),
    ran_td: 272,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 255,
    mnm_td: (245..248),
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
    skin: "direbear fang",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The direbear is a huge powerful beast with baleful red eyes that seem to bore through to the very soul. Impressively large bone deposits protrude across the breadth of the beast's back and neck. Large teeth that seem too big even for the massive maw can easily be seen even when the powerful jaws are closed. Mist, or perhaps tendrils of smoke, occasionally drift up from the flaring nostrils. Sharp eyes, a sense of smell to match, and a cunning said to rival demons make a direbear something to be avoid."
    ],
    arrival: [
      "A direbear lumbers in, balefully surveying the area with bloodshot red eyes!",
      "A direbear lumbers in!",
      "A direbear shudders and lumbers in, snarling in agony!",
      "A direbear slowly lumbers in, growling in pain!"
    ],
    flee: [
      "A direbear lumbers {direction}.",
      "A direbear slowly lumbers {direction}, growling in pain.",
      "A direbear shudders and lumbers {direction}, snarling in agony.",
      "A direbear crawls {direction}.",
      "A direbear slowly backs away, {pronoun} teeth bared.",
      "A direbear lumbers {direction}, balefully surveying the area with bloodshot red eyes!"
    ],
    death: [
      "The direbear collapses heavily into a heap on the ground and dies.",
      "The direbear lets out a blood-curdling roar and dies."
    ],
    decay: [
      "A direbear decays into a compost of fangs, fur and claws."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A direbear shakes off the stun!"
    ],
    attacks: {
      attack: [
        "A direbear charges at you, but seeing {pronoun} coming, you acrobatically spring over the direbear!",
        "A direbear's face contorts as {pronoun} unleashes a gutteral, deep-throated growl at you!"
      ],
      bite: [
        "A direbear tries to bite you!"
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
