{
  schema_version: 3,
  name: "bog troll",
  noun: "troll",
  url: "https://gswiki.play.net/bog_troll",
  picture: "",
  level: 35,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Miasmal Forest",
      uids: [5003001..5003027, 5003030..5003030, 5003032..5003032, 5003036..5003050, 5004001..5004034]
    },
    {
      name: "unmapped",
      uids: [5003028..5003029, 5003031..5003031, 5003033..5003035]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Thick Wooden Knurl",
        as: (244..314)
      },
      {
        name: "Claw",
        as: 234
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
    melee: (135..243),
    ranged: (121..177),
    bolt: (121..177),
    udf: 214,
    bar_td: nil,
    cle_td: 120,
    emp_td: 120,
    pal_td: (117..120),
    ran_td: 120,
    sor_td: (122..130),
    wiz_td: nil,
    mje_td: 124,
    mne_td: 124,
    mjs_td: (156..164),
    mns_td: (156..164),
    mnm_td: (105..112),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a thick wooden knurl",
    "some weed-covered brigandine"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "troll ear",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Hunched over and bow-legged, the bog troll bears many resemblances to the frogs that inhabit the bogs along with it. Its skin is a dark yellow mottled with patches of brownish green. Its mouth, wide and thick-lipped, displays rows of misaligned, jagged teeth, and the troll keeps a constant grin, as if its teeth are too large for it to completely close its mouth. Bulbous green eyes sit nearly atop its flat cranium, and sharp claws extend from its oversized, webbed hands and feet."
    ],
    arrival: [
      "A bog troll lumbers in, {pronoun} face set in an angry scowl!",
      "A bog troll just arrived!"
    ],
    flee: [
      "A bog troll runs {direction}.",
      "A bog troll lumbers {direction}, {pronoun} face set in an angry scowl!"
    ],
    death: [
      "The bog troll twitches violently, then dies.",
      "The bog troll tries to get back up but finally collapses and goes still."
    ],
    decay: [
      "A bog troll decays into compost."
    ],
    search: [],
    spell_prep: [
      "A bog troll mutters, \"Gr'r'r'ra.\""
    ],
    attacks: {
      attack: [
        "A bog troll swings {weapon} at you!"
      ],
      claw: [
        "A bog troll claws at you!"
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
