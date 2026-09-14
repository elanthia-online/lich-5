{
  schema_version: 3,
  name: "gremlock",
  noun: "gremlock",
  url: "https://gswiki.play.net/gremlock",
  picture: "",
  level: 84,
  family: "Gremlin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: 4,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17002201..17002247, 17002301..17002325, 17003011..17003038, 17003101..17003150, 17003201..17003217]
    },
    {
      name: "unmapped",
      uids: [17003001..17003010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (325..427)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Garrote"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (339..614),
    ranged: (319..451),
    bolt: 302,
    udf: (388..727),
    bar_td: (297..306),
    cle_td: (332..341),
    emp_td: (326..335),
    pal_td: (282..294),
    ran_td: (282..288),
    sor_td: (338..357),
    wiz_td: nil,
    mje_td: (361..364),
    mne_td: (361..364),
    mjs_td: (347..351),
    mns_td: (347..351),
    mnm_td: (264..273),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dusty knapsack",
    "a filthy knapsack",
    "a ragged knapsack",
    "a rusted wire garrote",
    "a stained knapsack",
    "a tattered knapsack"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Radiant crimson essence dust",
      "tiny golden seed",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The gremlock is larger than her relative, the gremlin, stretching five to six feet in height. The back hunched over from her time spent in the shadows stalking her prey, her actual height cannot be determined accurately. Tufts of dirty fur form a straggly mane around the savage looking face. Her long bulky arms tipped with massive claws only add to the deformity of the gremlock with her razor-sharp maw and potentially fatal, hungry glare."
    ],
    arrival: [
      "A stick flies in and skips along the floor drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A pebble flies in and skips along the floor drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A rock flies in and skips along the floor drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A pebble flies in and skips along the ground drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A rock flies in and skips along the ground drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A stick flies in and skips along the ground drawing your attention.  As you return to your original focus, you see a gremlock!",
      "A gremlock stomps in angrily!"
    ],
    flee: [
      "A gremlock sneaks {direction}.",
      "A gremlock shambles northeast shrieking at the top of {pronoun} voice.",
      "A gremlock shambles north shrieking at the top of {pronoun} voice."
    ],
    death: [
      "A gremlock's eyes roll up as {pronoun} dies.",
      "A gremlock collapses and {pronoun} eyes roll up as {pronoun} dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A gremlock claws at you!"
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
