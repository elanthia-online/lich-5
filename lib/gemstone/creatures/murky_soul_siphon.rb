{
  schema_version: 3,
  name: "murky soul siphon",
  noun: "siphon",
  url: "https://gswiki.play.net/murky_soul_siphon",
  picture: "",
  level: 106,
  family: "Siphon",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 241,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4571001..4571030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dual armrake",
        as: 471
      },
      {
        name: "Bladed forearms",
        as: (477..491)
      },
      {
        name: "Barbed tentacle",
        as: 436
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Limb Disruption (708)",
        cs: 447
      },
      {
        name: "Wither (1115)",
        cs: 437
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      }
    ],
    maneuvers: [
      {
        name: "Hamstring"
      },
      {
        name: "Lash"
      },
      {
        name: "Rear"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (265..381),
    bolt: (265..381),
    udf: (517..624),
    bar_td: 413,
    cle_td: (442..450),
    emp_td: (433..442),
    pal_td: (374..383),
    ran_td: (381..390),
    sor_td: nil,
    wiz_td: 482,
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A murky soul siphon can be found in the Scatter in the Rift. This is an undead entity subsisting upon the souls of the living. Classified as a semi, it uses various debuff spells to set up its foes for easier consumption. Its attacks have a chance to drain spirit and they also make use of a maneuver-based grasp to suck spirit from characters.\n\nThough it has a vaguely humanoid shape, the soul siphon is unlike anything that inhabits the walking world -- rather, it resembles something that escaped from the fevered nightmares of the deranged. Completely hairless, its skin is a dirty pink hue, blemished with ruddy patches. Where its face should be, there is nothing more than a sunken cavern, as if a stone giant's fist made an impression in the creature's head, crushing all of its features and leaving nothing but a gaping black void. Its arms are elongated, and instead of hands, it has scythe-shaped blades of bone and flesh. Its legs seem to be twisted, causing it to walk with an awkward gait."
    ],
    arrival: [
      "A murky soul siphon scampers in on its crooked legs.",
      "A murky soul siphon scuttles in on {pronoun} crooked legs.",
      "A murky soul siphon scurries in on {pronoun} crooked legs.",
      "A murky soul siphon scurries in on {pronoun} wounded legs.",
      "A murky soul siphon scuttles in on {pronoun} wounded legs."
    ],
    flee: [
      "A murky soul siphon scampers northeast on {pronoun} crooked legs.",
      "A murky soul siphon scampers up on {pronoun} crooked legs.",
      "A murky soul siphon scuttles northwest on {pronoun} crooked legs.",
      "A murky soul siphon scampers down on {pronoun} crooked legs.",
      "A murky soul siphon scurries up on {pronoun} wounded legs."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A murky soul siphon rakes at you with {pronoun} bladed forearms!",
        "The shadows of a murky soul siphon's face briefly resolve into a gaping maw filled with concentric rows of teeth that attempt to close on you!",
        "The murky soul siphon slashes {pronoun} right arm across your body!",
        "The murky soul siphon thrusts at {target} with {pronoun} right arm!",
        "The murky soul siphon slashes {pronoun} left arm across your body!",
        "The murky soul siphon thrusts unexpectedly with {pronoun} right arm!",
        "The murky soul siphon slashes {pronoun} left arm across {target} body!",
        "The murky soul siphon slashes {pronoun} right arm across {target} body!",
        "The murky soul siphon thrusts unexpectedly with {pronoun} left arm!",
        "A murky soul siphon rears back before thrusting one bladed arm at you!"
      ],
      claw: [
        "A murky soul siphon rakes at you with {pronoun} bladed forearms!",
        "A murky soul siphon rakes at {target} with {pronoun} bladed forearms!",
        "A murky soul siphon rakes at a murky soul siphon with {pronoun} bladed forearms!"
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
