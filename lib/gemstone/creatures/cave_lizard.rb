{
  schema_version: 3,
  name: "cave lizard",
  noun: "lizard",
  url: "https://gswiki.play.net/cave_lizard",
  picture: "",
  level: 18,
  family: "Reptilian",
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
  max_hp: 167,
  speed: 10,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Czeroth Caverns",
      uids: [13007001..13007043]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (183..203)
      },
      {
        name: "Bite",
        as: 189
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tail Sweep"
      },
      {
        name: "Tail Swipe"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (109..209),
    ranged: (81..150),
    bolt: (81..150),
    udf: (122..189),
    bar_td: 54,
    cle_td: (54..60),
    emp_td: (54..62),
    pal_td: (51..60),
    ran_td: (51..60),
    sor_td: (48..57),
    wiz_td: nil,
    mje_td: (51..57),
    mne_td: (51..57),
    mjs_td: (51..60),
    mns_td: (51..60),
    mnm_td: (48..57),
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
    gems: true,
    boxes: false,
    skin: "a stone-grey lizard tail",
    other: [
      "s'ayanad crystal",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "When safe in the confines of its underground home, the cave lizard is easily mistaken for just another rock on the floor, albeit a rather long, thick rock. Its low-slung body and stubby legs allow it to squeeze through cracks that would defy attempts by the smaller humanoid races. A mottled, scaly hide of charcoal grey intermixed with deep crimson helps it hide in low light conditions. Bright light reveals not only the more scintillating aspects of its crimson coloration but rows of razor-sharp teeth set in a protruding snout. One should not fixate on the snout, though, lest the powerful tail of the cave lizard land a devastating blow."
    ],
    arrival: [
      "A dance of dust and gravel heralds the arrival of a speckled cave lizard!",
      "A dance of dust and gravel heralds the arrival of a cave lizard!",
      "A cave lizard scuttles in, moaning in pain."
    ],
    flee: [
      "A speckled cave lizard plods {direction}.",
      "A cave lizard plods {direction}."
    ],
    death: [
      "The cave lizard shudders a final time and goes still.",
      "A cave lizard collapses leaving nothing but a few scales and teeth behind."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "The cave lizard throws up copious amounts of blood and what appears to be an internal organ!"
      ],
      claw: [
        "A cave lizard claws at you!"
      ],
      bite: [
        "A cave lizard tries to bite you!"
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
