{
  schema_version: 3,
  name: "waern",
  noun: "waern",
  url: "https://gswiki.play.net/waern",
  picture: "",
  level: 49,
  family: "Canine",
  type: "Quadruped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 262,
  speed: 6,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Bonespear Tower",
      uids: [319001..319015, 319117..319139]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (257..295)
      },
      {
        name: "Charge",
        as: (286..294)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Grapple"
      },
      {
        name: "Lunge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (195..328),
    ranged: (248..269),
    bolt: (251..269),
    udf: (275..370),
    bar_td: 165,
    cle_td: 180,
    emp_td: (170..179),
    pal_td: (144..153),
    ran_td: nil,
    sor_td: (190..199),
    wiz_td: 200,
    mje_td: (199..203),
    mne_td: (199..203),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: (144..153),
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
    gems: false,
    boxes: true,
    skin: "a waern fur",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The waern is a vicious-looking embodiment of canine malice and tenacity. The waern's fiendish green eyes glow with insane appetite and her mangy pelt is so ragged, the rotting bones show through in spots. Long, malicious teeth curve out of the waern's rotting muzzle, and the tail that curves over the waern's back is hardly more than segments of bone interspersed with a few pieces of fuzzy, matted hair. Floating over the ground, her paws scarcely leaving a track, the waern dodges almost quicker than the eye can follow."
    ],
    arrival: [
      "A waern just arrived.",
      "A waern pads into the area, slavering hungrily!",
      "A waern just came through an iron door.",
      "A waern just came through a tall archway."
    ],
    flee: [
      "A waern runs {direction}.",
      "A waern just went through an iron door.",
      "A waern whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The waern rolls over and dies.",
      "The waern falls to the ground and dies."
    ],
    decay: [
      "A waern decays into a compost of fangs and fur.",
      "A muculent waern decays into a compost of fangs and fur.",
      "A slimy waern decays into a compost of fangs and fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A waern shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    stand: [
      "A waern growls as {pronoun} scrambles to {pronoun} feet!"
    ],
    attacks: {
      attack: [
        "A waern charges at you!",
        "A waern lunges at you!",
        "A waern bares {pronoun} teeth hungrily at you!"
      ],
      claw: [
        "A waern claws at you!"
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
