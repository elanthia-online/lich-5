{
  schema_version: 3,
  name: "eidolon",
  noun: "eidolon",
  url: "https://gswiki.play.net/eidolon",
  picture: "",
  level: 55,
  family: "Eidolon",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 240,
  speed: nil,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Bonespear Tower",
      uids: [319117..319140]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: (248..307)
      }
    ],
    bolt_spells: [],
    warding_spells: [
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
        name: "Torment (718)"
      },
      {
        name: "Repel (fear)",
        cs: 251
      },
      {
        name: "Point",
        cs: 272
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (281..410),
    ranged: (282..389),
    bolt: (282..389),
    udf: (364..452),
    bar_td: (179..209),
    cle_td: (234..240),
    emp_td: (213..224),
    pal_td: (190..200),
    ran_td: (204..207),
    sor_td: (245..254),
    wiz_td: nil,
    mje_td: 244,
    mne_td: (217..252),
    mjs_td: 248,
    mns_td: 248,
    mnm_td: (211..218),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Lesser Shroud (120)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened staff",
    "some tattered robes"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The eidolon is a nightmarish vision of pure evil, appearing from the shadows like a disconcerting fragment of thought that haunts you relentlessly. The eidolon's eyes shine out of its ephemeral silhouette like twin coals, radiating hatred and hunger. The monstrous apparition is as big as it is misshapen, towering over a tall giantman as it moves in rapid spurts that defy the eye's ability to follow its progress. As it conjures and strikes, its extremities contort and blur through each other, amplifying its grotesque demeanor."
    ],
    arrival: [
      "An eidolon just arrived.",
      "An eidolon just came through an iron door."
    ],
    flee: [
      "An eidolon floats {direction}.",
      "An eidolon just went through a tall archway.",
      "An eidolon just went through an iron door."
    ],
    death: [
      "An eidolon fades into oblivion.",
      "The eidolon falls to the floor dead, {pronoun} ethereal mist still pulsating with a blinding white hue."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An eidolon exhales the last of a virulent green mist.",
        "An eidolon exhales a virulent green mist toward you, but you are unaffected."
      ],
      cast: [
        "An eidolon points a spectral finger at {target}!"
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
