{
  schema_version: 3,
  name: "triton fanatic",
  noun: "fanatic",
  url: "https://gswiki.play.net/triton_fanatic",
  picture: "",
  level: 100,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Atoll",
      uids: [7138201..7138218]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hammer of Kai",
        as: (423..539)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Pious Trial (1602)",
        cs: (430..442)
      },
      {
        name: "Repentance (1615)",
        cs: (430..442)
      },
      {
        name: "Point",
        cs: 454
      }
    ],
    offensive_spells: [
      {
        name: "Arm of the Arkati (1605)"
      },
      {
        name: "Zealot (1617)"
      },
      {
        name: "Fervor (1618)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Lash"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Cyclone"
      },
      {
        name: "Mstrike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "17N",
    immunities: [],
    melee: (80..344),
    ranged: (106..286),
    bolt: (106..286),
    udf: (374..455),
    bar_td: nil,
    cle_td: 469,
    emp_td: (418..440),
    pal_td: (360..370),
    ran_td: 414,
    sor_td: (422..455),
    wiz_td: nil,
    mje_td: (462..472),
    mne_td: (433..468),
    mjs_td: (354..444),
    mns_td: (354..444),
    mnm_td: (408..417),
    defensive_spells: [
      "Mantle of Faith (1601)",
      "Higher Vision (1610)",
      "Patron's Blessing (1611)",
      "Faith Shield (1619)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a corroded bronze Hammer of Kai"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "thick triton spine",
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: [
      "drake greatsword"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "A triton fanatic visibly twitches as he clutches a contorted driftwood fetish within his sigil-gouged fingers, his crazed bloodshot eyes darting to and fro beneath a shredded miter of dark oilskin. The last vestiges of a hair-sewn tunic barely cling to his emaciated form, stained in rust-colored splotches from collar to knee, and lashed together with knots of thick sinew. Branded across his forehead is the image of a broken trident, the forks splayed between his brows."
    ],
    arrival: [
      "A triton fanatic just arrived.",
      "A triton fanatic just arrived, limping.",
      "A triton fanatic just arrived, looking terrified.",
      "A triton fanatic just arrived, crawling along the ground."
    ],
    flee: [
      "A triton fanatic heads {direction}.",
      "A triton fanatic limps {direction}.",
      "A triton fanatic withdraws, disengaging from you."
    ],
    death: [
      "The triton fanatic gurgles once and goes still, a wrathful look on {pronoun} face.",
      "A triton fanatic goes limp as the last of {pronoun} life is crushed from {pronoun} by {target} unyielding bearhug!",
      "The triton fanatic collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton fanatic's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [
      "A triton fanatic searches methodically through the environs.",
      "A triton fanatic glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [
      "A triton fanatic's eyes glow with silvery grey light, and then everything around you shimmers to match the argentine color.",
      "A triton fanatic's eyes glow with silvery grey light, and a pillar of argentine radiance manifests around {target}.",
      "A triton fanatic steeples {pronoun} clawed fingers together, murmuring a quick incantation."
    ],
    attacks: {
      attack: [
        "A triton fanatic swings {weapon} at you!",
        "A triton fanatic charges into view, {pronoun} determination clear in {pronoun} battle-ready stance!"
      ],
      charge: [
        "A triton fanatic rushes forward at you with {pronoun} bronze Hammer of Kai and attempts a charge!",
        "A triton fanatic rushes forward at you with {pronoun} {weapon} and attempts a charge!",
        "A triton fanatic rushes forward at {target} with {pronoun} {weapon} and attempts a charge!"
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
