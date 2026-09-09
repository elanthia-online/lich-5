{
  name: "savage fork-tongued wendigo",
  noun: "wendigo",
  url: "https://gswiki.play.net/Savage_fork-tongued_wendigo",
  picture: "",
  level: 105,
  family: "humanoid",
  type: "biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [],
  areas: [
    {
      name: "Hinterwilds",
      uids: [7503101..7503146]
    }
  ],
  bcs: true,
  max_hp: 600,
  speed: 6,
  height: 8,
  size: "large",
  attack_attributes: {
    physical_attacks: [
      {
        name: "attack",
        as: (530..630)
      },
      {
        name: "bite (attack)",
        as: (505..605)
      },
      {
        name: "claw (attack)",
        as: (515..615)
      },
      {
        name: "Elongated talon",
        as: (481..628)
      },
      {
        name: "Clawed fists",
        as: (475..636)
      },
      {
        name: "Shark-like teeth",
        as: (612..625)
      },
      {
        name: "Charge",
        as: 529
      },
      {
        name: "Huge hooves",
        as: 517
      },
      {
        name: "Tusks",
        as: 525
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "frenzy (216)",
        cs: (438..450)
      },
      {
        name: "sympathy (1120)",
        cs: (438..450)
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "enrage", # wiki calls this Attack Strength boost
        note: "+100 AS"
      },
      {
        name: "mstrike",
        note: "x5"
      }
    ]
  },
  defense_attributes: {
    asg: "10N",
    immunities: [],
    melee: (285..711),
    ranged: (285..459),
    bolt: (285..459),
    udf: (558..840),
    bar_td: (432..434),
    cle_td: (447..459),
    emp_td: 461,
    pal_td: (406..415),
    ran_td: (396..403),
    sor_td: (471..486),
    wiz_td: nil,
    mje_td: (489..510),
    mne_td: (489..510),
    mjs_td: nil,
    mns_td: (444),
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  equipment: [
    "a firewheel arrow fletched with plain white feathers",
    "a twisted obsidian dagger",
    "a riveted golden targe"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: [
      "drake greatsword",
      "drake falchion",
      "drake scimitar",
      "drake mace",
      "feras mattock",
      "feras falchion",
      "drake yierka-spur",
      "drake greataxe",
      "feras mace",
      "feras dagger",
      "feras hammer",
      "feras rapier",
      "drake dagger",
      "feras tiger-claw"
    ],
    transmogs: nil
  },
  messaging: {
    description: "The wendigo looks to have once been humanoid.  Magics have contorted and stretched its form into an atrocity of exposed bone and raw tissues that stands several heads taller than a giantman.  Sprouting antlers of bloodstained bone breach up from the sparse flesh of the wendigo's skull.  Its eyes are misty pools of light that cast the rest of the wendigo's face in haunted shadow.  The abomination's maw is forced open by multifarious rows of shark-like teeth, but its tongue is forked like that of a snake.",
    arrival: [
      "A savage fork-tongued wendigo steps in, eyes like luminous pools searching the surroundings.",
      "A savage fork-tongued wendigo steps in, luminous eyes hungrily eyeing the surroundings despite its grievous wounds.",
      "Eyes like twin pools of ghostly light materialize through the falling snow, illuminating the abominable shape of a savage fork-tongued wendigo.  The creature races forward with unnatural speed, mouth opening unnaturally wide as it bares rows of shark-like teeth.",
      "A savage fork-tongued wendigo stalks in, eyes like luminous pools searching the surroundings.",
      "A savage fork-tongued wendigo just arrived.",
      "A savage fork-tongued wendigo just came through a break in the trees."
    ],
    flee: [
      "Heedless of its grievous wounds, a savage fork-tongued wendigo stalks {direction}.",
      "A savage fork-tongued wendigo gets down on all fours and sprints {direction} at unnatural speed.",
      "A savage fork-tongued wendigo's luminous eyes flare with unnatural light as it turns and stalks {direction}.",
      "A savage fork-tongued wendigo just went through a break in the trees.",
      "A savage fork-tongued wendigo just went into a thatched timber smithy.",
      "A savage fork-tongued wendigo just went down a shrouded path.",
      "A savage fork-tongued wendigo just went into a huge hoarbeam longhouse.",
      "A savage fork-tongued wendigo just went into a huge hut.",
      "A savage fork-tongued wendigo just went through a crumbling red stone maw."
    ],
    death: [
      "Rage flickers in the wendigo's eyes as it collapses, bloody maw still working hungrily until the last hint of life goes out of its form."
    ],
    decay: [
      "Rot sets into a savage fork-tongued wendigo's body with unnatural speed, skin sloughing away to reveal greying muscle and rampant suppuration.  In moments, all that remain are yellowing bones and stinking effluvia."
    ],
    search: [
      "A savage fork-tongued wendigo tilts its head, eyeing the shadows with a hideous smile upon its face.",
      "A savage fork-tongued wendigo's eyes dart around, suspicion warring with hunger in its beady eyes."
    ],
    spell_prep: [
      "A savage fork-tongued wendigo rasps out a dissonant, sing-song phrase.",
      "A savage fork-tongued wendigo closes {pronoun} eyes in deep concentration..."
    ],

    attacks: {
      attack: [
        "With inhuman swiftness and precision, a savage fork-tongued wendigo swings its {weapon} at you!"
      ],
      bite: [
        "A savage fork-tongued wendigo's jaw unhinges as it tries to ravage you with its shark-like teeth!"
      ],
      claw: [
        "Lashing out unpredictably, a savage fork-tongued wendigo slices at you with an elongated talon!",
        "A savage fork-tongued wendigo flails with its clawed fists at you!"
      ]
    },
    stun_break: [
      "A savage fork-tongued wendigo throws {pronoun} head back and lets out a bone-shaking roar, ripping free of the magics restraining {pronoun} in a wash of bloody light."
    ],
    frenzy: "A savage fork-tongued wendigo crooks an oddly elongated finger at you!",
    enrage: "A savage fork-tongued wendigo's eyes blaze a murderous crimson!",
    mstrike: "In an awe-inspiring display of combat mastery, a savage fork-tongued wendigo engages you in a furious dance macabre, spiraling into a blur of strikes and ripostes!",
  }
}

=begin


# make you mad spell  Frenzy?
  A savage fork-tongued wendigo rasps out a dissonant, sing-song phrase.
  >
  A savage fork-tongued wendigo crooks an oddly elongated finger at you!
    CS: +450 - TD: +441 + CvA: +4 + d100: +88 == +101
    Warding failed!
  Anger beyond all reason boils up within you!


# some aoe spell... Sympathy?
  A savage fork-tongued wendigo points skyward with a single gristly talon!
  A savage fork-tongued wendigo closes its eyes in deep concentration...

  An echo of foreign thought brushes your mind.
    CS: +450 - TD: +478 + CvA: +4 + d100: +20 == -4
    Warded off!
  You blink a few times.

    CS: +450 - TD: +403 + CvA: +25 + d100: +26 == +98
    Warded off!
  A niveous giant warg blinks a few times.

  A savage fork-tongued wendigo opens its eyes, looking less focused.



# cyclone?  frigid cyclone in room
  The air grows even colder as an intensely localized cyclone forms overhead, assailing the area with an onslaught of snow and icy wind.

  Shrill wind gusts from the cyclone, howling through the area in a stinging onslaught.
  [SMR result: 179 (Open d100: 193, Penalty: 7)]
  Cold air strikes you with the force of a great fist, knocking you to the ground!
    ... 10 points of damage!
    You just got the cold shoulder!
  Roundtime: 7 sec.

  A frigid cyclone fluctuates before dissipating with a last gust of frigid wind.



# Jump up and flee
  A savage fork-tongued wendigo jerks up from the ground in a single boneless motion.
  Heedless of its grievous wounds, a savage fork-tongued wendigo stalks northwest.

  A savage fork-tongued wendigo points skyward with a single gristly talon!
  A savage fork-tongued wendigo gets an intense expression.

  A savage fork-tongued wendigo tilts its head slowly to an unnatural angle.  Its forked tongue protrudes from split lips, tasting the air ravenously.


  A savage fork-tongued wendigo tilts its head, eyeing the shadows with a hideous smile upon its face.
  A savage fork-tongued wendigo extends an elongated finger, pointing toward you in your hiding place!
=end
