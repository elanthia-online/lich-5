{
  schema_version: 3,
  name: "vesperti",
  noun: "vesperti",
  url: "https://gswiki.play.net/vesperti",
  picture: "",
  level: 38,
  family: "Vesperti",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: true,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: "miniboss",
  otherclass: [
    "Anti-mana"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Deep Woods",
      uids: [4007001..4007038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail",
        as: 229
      },
      {
        name: "Whip",
        as: 229
      },
      {
        name: "Scimitar",
        as: 229
      },
      {
        name: "Blackened cutlass",
        as: 202
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Energy Maelstrom (710)"
      },
      {
        name: "Pain (711)"
      },
      {
        name: "Curse (715)"
      },
      {
        name: "Pestilence (716)"
      },
      {
        name: "Mana Drain"
      },
      {
        name: "Claw Curse",
        cs: 206
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Dodge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: ["magic"],
    melee: (218..281),
    ranged: (172..263),
    bolt: (172..263),
    udf: (232..331),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a barbed whip",
    "a blackened cutlass",
    "a spiked flail",
    "a spiked shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a vesperti claw",
    other: "Glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The vesperti stands roughly six feet tall, with coarse black fur covering his willowy frame. A veined membrane of skin extends from his ankle up to his wrists, edges scalloped like those of a bat's wings. Capping off the wings are taloned hands and feet, the long, tapered digits bearing glossy black claws. Intense eyes stare out from beneath a mane of tousled hair, looking far too sentient for any measure of comfort."
    ],
    arrival: [
      "With a flurry of {pronoun} wings, a vesperti flies in!"
    ],
    flee: [
      "With a flurry of her wings, a lustrous vesperti flies {direction}.",
      "With a flurry of {pronoun} wings, a vesperti flies {direction}."
    ],
    death: [
      "The vesperti twitches violently, then dies.",
      "The vesperti's wings splay out as {pronoun} goes still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A vesperti swings {weapon} at you!",
        "A vesperti exhales the last of a virulent green mist."
      ],
      cast: [
        "A vesperti points a clawed finger at you!"
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
