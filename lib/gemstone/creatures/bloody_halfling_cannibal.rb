{
  name: "bloody halfling cannibal",
  noun: "cannibal",
  url: "https://gswiki.play.net/Bloody_halfling_cannibal",
  picture: "",
  level: 101,
  family: "humanoid",
  type: "biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
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
  max_hp: 377,
  speed: 6,
  height: 3,
  size: "small",
  attack_attributes: {
    physical_attacks: [
      {
        name: "bite",
        as: 474
      },
      {
        name: "grimy little fists",
        as: (464..544)
      },
      {
        name: "hurtle",
        as: (327..564)
      },
      {
        name: "wiry arms",
        as: (464..544)
      },
      {
        name: "Clawed fists",
        as: (475..585)
      },
      {
        name: "Feras mattock",
        as: 489
      },
      {
        name: "Twisted obsidian dagger",
        as: (584..606)
      },
      {
        name: "Charge",
        as: 529
      },
      {
        name: "Huge hooves",
        as: 525
      },
      {
        name: "Shark-like teeth",
        as: (505..573)
      },
      {
        name: "Tusks",
        as: (531..544)
      },
      {
        name: "Lunge",
        as: 520
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "cannibalize"
      }
    ],
    special_abilities: [
      {
        name: "hunger",
        note: "+80 AS"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (269..646),
    ranged: (269..471),
    bolt: (269..471),
    udf: (535..805),
    bar_td: (364..379),
    cle_td: (378..464),
    emp_td: 428,
    pal_td: (338..347),
    ran_td: (335..396),
    sor_td: (413..422),
    wiz_td: nil,
    mje_td: (428..445),
    mne_td: (428..445),
    mjs_td: nil,
    mns_td: 381,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [
      {
        name: "unstun",
        note: "able to break stuns"
      },
      {
        name: "vanish",
        note: "able to evade an attack by hiding in the shadows"
      }
    ],
    special_defenses: []
  },
  special_other: "",
  abilities: [
    {
      id: :frenzy,
      name: "Frenzy",
      type: :buff,
      target: :self,
      messaging: [
        "A bloody halfling cannibal bares {pronoun} teeth in a mad parody of a grin as {pronoun} bloodlust rises!",
        "A bloody halfling cannibal succumbs further to {pronoun} bloodlust as spittle drips from {pronoun} open mouth!"
      ]
    }
  ],
  alchemy: [],
  equipment: [
    "a twisted obsidian dagger",
    "some frayed armor scraps adorned with glinting blue-white scales"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: false,
    other: [
      "gigas artifact",
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: [
      "drake falchion",
      "drake greatsword",
      "drake scimitar",
      "drake mace",
      "feras mattock",
      "drake greataxe",
      "feras falchion",
      "feras hammer",
      "feras mace"
    ],
    transmogs: nil
  },
  messaging: {
    description: "A skim of dark, congealing blood slicks the features of the raw-boned halfling.  {pronoun} eyes are black as burnt coals and feverish with single-minded hunger, a hunger that has burnt away every last shred of fat from {pronoun} body and left behind only knotted sinew.  The cannibal's teeth are sharpened to jagged points, and from between them darts a tiny pink tongue that is constantly tasting the air.  {pronoun} wears tattered, weather-eaten remains of furs and homespun fabric.  They, too, are soaked red with blood.",
    arrival: [
      "Accompanied by the fetid stench of old meat, a bloody halfling cannibal races into the area with a froth of bloody saliva on {pronoun} lips.",
      "A bloody halfling cannibal lurches in, grinning madly despite {pronoun} crippling wounds."
    ],
    flee: [
      "Licking {pronoun} lips ravenously, a bloody halfling cannibal creeps {direction}.",
      "A bloody halfling cannibal just went down a narrow path.",
      "A bloody halfling cannibal just went into a huge hut."
    ],
    death: [
      "A monstrous, too-wide smile spreads across the cannibal's face as {pronoun} collapses to the ground, dead."
    ],
    decay: [
      "A bloody halfling cannibal's body rots away, leaving only a small stain on the ground.",
      "With a moan, a bloody halfling cannibal begins to weep piteously, but the sound swiftly dissolves into a cascade of insane laughter."
    ],
    search: [
      "A bloody halfling cannibal sniffs at the air, {pronoun} eyes glinting as {pronoun} searches the shadows.",
      "a bloody halfling cannibal's eyes dart around, suspicion warring with hunger in {pronoun} beady eyes."
    ],
    bite: "A bloody halfling cannibal bares {pronoun} sharpened teeth as {pronoun} tries to bite into you!",

    stun_break: [
      "A bloody halfling cannibal gurgles out an animalistic shriek of rage, {pronoun} eyes filling with bloody blackness as {pronoun} surges back into action!"
    ],
    attacks: {
      attack: [
        "A bloody halfling cannibal bares {pronoun} sharpened teeth as {pronoun} tries to bite into you!",
        "A bloody halfling cannibal hammers blindly at you with grimy little fists!",
        "A bloody halfling cannibal hurtles at you, swinging wildly with a feras mattock!",
        "A bloody halfling cannibal hurtles at you, swinging wildly with a twisted obsidian dagger!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and bares {pronoun} sharpened teeth as {pronoun} tries to bite into you!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and hammers blindly at you with grimy little fists!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and hurtles at you, swinging wildly with a feras mattock!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and hurtles at you, swinging wildly with a twisted obsidian dagger!",
        "A bloody halfling cannibal throws {pronoun} wiry arms around you, fueled by panicked hunger!",
        "A bloody halfling cannibal throws {pronoun} wiry arms around {target}, fueled by panicked hunger!"
      ],
      cannibalize: [
        "A bloody halfling cannibal falls into a lopsided crouch.  The muscles of {pronoun} hindquarters tense as {pronoun} springs toward you, sharpened teeth gnashing."
      ],
      grimy_little_fists: [
        "A bloody halfling cannibal hammers blindly at you with grimy little fists!"
      ],
      hurtle: [
        "A bloody halfling cannibal hurtles at you, swinging wildly with a twisted obsidian dagger!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and hurtles at you, swinging wildly with a twisted obsidian dagger!"
      ],
      wiry_arms: [
        "A bloody halfling cannibal throws her wiry arms around you, fueled by panicked hunger!",
        "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and throws {pronoun} wiry arms around you, fueled by panicked hunger!"
      ]
    },
    triggers: {
      hide: [
        "A bloody halfling cannibal darts into the shadows."
      ],
      vanish: [
        "As you move to attack a bloody halfling cannibal, the cannibal shrinks away from you, baring sharpened teeth as {pronoun} darts into the shadows!"
      ],
      hunger: [
        "A bloody halfling cannibal's eyes grow bloodshot with ravening hunger!"
      ]
    },
    info: {
      general: [
        "* Despite being the lowest level creature in the Hinterwilds, cannibals can't be underestimated or ignored, especially if the Boreal Forest has started filling up. Cannibals' namesake biting maneuver can be lethal if its standard maneuver roll gets a significant bonus from other creatures in the area stunning or otherwise disabling a character. Cannibals also take advantage of stealth, which means they can get stance pushdown from ambush mechanics in situations where you might never have seen them coming. As such, even in cases where relatively low-mana-cost AoE spells like Censure (316), Elemental Wave (410), or Grasp of the Grave (709) might seem unnecessary for the number of visible creatures, sometimes they can still be helpful in revealing the invisible threat of cannibals."
      ],
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
    frenzy: "A bloody halfling cannibal bares {pronoun} teeth in a mad parody of a grin as {pronoun} bloodlust rises!"
  }
}
