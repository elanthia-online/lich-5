{
  schema_version: 3,
  name: "arctic wolverine",
  noun: "wolverine",
  url: "https://gswiki.play.net/arctic_wolverine",
  picture: "",
  level: 24,
  family: "Mustelid",
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
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
  speed: 5,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Pinefar Forests",
      uids: [4563008..4563020]
    },
    {
      name: "Sleeping Lady Mountains",
      uids: [4565016..4565037]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (155..194)
      },
      {
        name: "Claw",
        as: (184..204)
      },
      {
        name: "(quarantine-recovered)",
        as: 238
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
    asg: "10N",
    immunities: [],
    melee: (106..191),
    ranged: (98..148),
    bolt: (98..148),
    udf: (145..194),
    bar_td: 72,
    cle_td: (69..78),
    emp_td: (72..80),
    pal_td: (69..78),
    ran_td: (66..75),
    sor_td: (66..75),
    wiz_td: nil,
    mje_td: 72,
    mne_td: 72,
    mjs_td: 96,
    mns_td: 96,
    mnm_td: 72,
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
    skin: "a wolverine tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Similar to his cousin of the more temperate climates, the arctic wolverine is possessed with a ferocious nature far out of proportion to his size, making him an extremely vicious opponent. Swift and agile, with claws and teeth backed by muscles like coiled springs, the arctic wolverine will take on and defeat foes three times his size. His shaggy hide is a mixture of light brown and icy white, affording him good cover in the frosty fields, and his toes are webbed, providing a snowshoe effect for increased agility in the snow."
    ],
    arrival: [
      "An arctic wolverine scampers in!",
      "An arctic wolverine scampers in, growling in pain!"
    ],
    flee: [
      "An arctic wolverine scampers {direction}, growling in pain.",
      "An arctic wolverine scampers {direction}.",
      "The arctic wolverine slowly backs away, {pronoun} teeth bared."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An arctic wolverine bares an impressive set of fangs at you!"
      ],
      claw: [
        "An arctic wolverine claws at you!"
      ],
      bite: [
        "An arctic wolverine tries to bite you!"
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
