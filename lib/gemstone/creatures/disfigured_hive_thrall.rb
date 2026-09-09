{
  schema_version: 3,
  name: "disfigured hive thrall",
  noun: "thrall",
  url: "https://gswiki.play.net/disfigured_hive_thrall",
  picture: "",
  level: 104,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 377,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Hive",
      uids: [13041101..13041132, 13041201..13041230, 13041301..13041329]
    },
    {
      name: "unmapped",
      uids: [13041330..13041330]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge"
      },
      {
        name: "Claw"
      },
      {
        name: "Barbed stinger",
        as: 557
      }
    ],
    bolt_spells: [
      {
        name: "Major Acid"
      },
      {
        name: "Web bolt"
      }
    ],
    warding_spells: [
      {
        name: "Wild Entropy"
      },
      {
        name: "Charge",
        cs: 447
      }
    ],
    offensive_spells: [
      {
        name: "Powersink"
      }
    ],
    maneuvers: [
      {
        name: "Bull Rush"
      },
      {
        name: "Bearhug"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Spirit Strike"
      },
      {
        name: "Project Misery"
      },
      {
        name: "Psychic Assault"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: nil,
    ranged: (376..501),
    bolt: (376..501),
    udf: (587..896),
    bar_td: nil,
    cle_td: (400..409),
    emp_td: 424,
    pal_td: (366..375),
    ran_td: (369..378),
    sor_td: nil,
    wiz_td: nil,
    mje_td: (469..475),
    mne_td: (469..475),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Iron Skin (1202)",
      "Foresight (1204)",
      "Focus Barrier (1216)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some tattered clothing scraps"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The thrall looks to have once been humanoid, but her form has been mutilated into a tortured, stooped shape with a mismatch of clashing parts. One eye is huge and insectoid, but the other remains painfully close to mammalian, its pupil bleeding into the bright green iris. Her jaw hangs slack, forced open at all times by a set of bristled mandibles that seem to have a mind of their own as they twitch and clench. Tumorous growths stud the thrall's spine, unsavory green where they are not blotchy violet-red with pustules. One has burst to reveal a single rudimentary wing that resembles a fly's."
    ],
    arrival: [
      "A disfigured hive thrall lurches in, burning ichor flowing freely from {pronoun} wounds.",
      "A disfigured hive thrall lurches in, burning ichor flowing freely from {pronoun} {weapon}."
    ],
    flee: [
      "A disfigured hive thrall gibbers pathetically as {pronoun} flees {direction}.",
      "A disfigured hive thrall gibbers pathetically as {pronoun} flees {direction}, burning ichor seeping from {pronoun} wounds."
    ],
    death: [],
    decay: [],
    search: [
      "A disfigured hive thrall fidgets, one eye twitching as {pronoun} searches the shadows."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A disfigured hive thrall desperately thrusts {weapon} at you!",
        "Misshapen limbs flail as a disfigured hive thrall flings {pronoun} at you!",
        "Twisted desperation contorts a disfigured hive thrall's warped features as disfigured hive thrall tries to grab at you!",
        "A disfigured hive thrall crushes you mercilessly!",
        "A disfigured hive thrall's eyes widen as {pronoun} topples forward, belching caustic bile at you!"
      ],
      bearhug: [
        "A disfigured hive thrall charges towards you and attempts to grasp you in a ferocious bearhug!"
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
