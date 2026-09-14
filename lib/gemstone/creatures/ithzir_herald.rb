{
  schema_version: 3,
  name: "Ithzir herald",
  noun: "herald",
  url: "https://gswiki.play.net/ithzir_herald",
  picture: "",
  level: 92,
  family: "Ithzir",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004001..17004028, 17004031..17004079, 17004160..17004168, 17004180..17004187, 17004190..17004195]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion"
      },
      {
        name: "Curved crystal-edged blade",
        as: 413
      },
      {
        name: "Curved silvery blade",
        as: (413..416)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Lullabye (1005)"
      },
      {
        name: "Song of Depression (1015)",
        cs: 384
      },
      {
        name: "Song of Rage (1016)"
      },
      {
        name: "Song of Sonic Disruption (1030)",
        cs: 384
      },
      {
        name: "Vibration Chant (1002)",
        cs: 384
      },
      {
        name: "Curved silvery blade",
        cs: 375
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Mass Calm (619)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9",
    immunities: [],
    melee: (346..570),
    ranged: (327..477),
    bolt: (327..477),
    udf: (449..621),
    bar_td: (358..371),
    cle_td: (364..382),
    emp_td: (361..370),
    pal_td: (312..322),
    ran_td: (311..316),
    sor_td: (399..409),
    wiz_td: nil,
    mje_td: 477,
    mne_td: 477,
    mjs_td: 385,
    mns_td: 385,
    mnm_td: (322..330),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Barrier (430)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a curved crystal-edged blade",
    "a curved silvery blade",
    "a gleaming crystal-edged broadsword",
    "a polished steel shield",
    "some sleek studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "crystal-edged weapons",
      "tiny golden seed"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "An Ithzir herald holds {pronoun} head as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      attack: [
        "An Ithzir herald swings {weapon} at you!",
        "The Ithzir herald points at you for emphasis.",
        "The Ithzir herald points at you.",
        "An Ithzir herald directs {pronoun} alien song at you!",
        "The Ithzir herald cocks {pronoun} head at you."
      ]
    },
    stand: [
      "An Ithzir herald rises to {pronoun} feet, {pronoun} green eyes blazing!"
    ],
    description: [
      "A trio of black tattooed stripes run from center of the Ithzir herald's forehead and over the crown of his bald, blue-skinned head. The Ithzir herald is slightly taller than a human, and while his humanoid form is similar to scores of other races, the hairless, blue body is nonetheless alien in its appearance. The herald wears a fine silvery-blue tunic crossed with a green tabard."
    ],
    arrival: [
      "An Ithzir initiate strides in, {pronoun} hands clasped before him.",
      "An Ithzir herald strolls in, humming softly to {pronoun}.",
      "An Ithzir herald strolls in, humming softly to {reflexive}."
    ],
    flee: [
      "An Ithzir herald limps {direction}."
    ],
    death: [
      "The Ithzir herald vainly struggles to rise, then goes still.",
      "An Ithzir herald's body shimmers slightly, then fades from view like a dissipating phantom."
    ],
    decay: [],
    search: [],
    spell_prep: [],
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
