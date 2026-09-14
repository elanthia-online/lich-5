{
  schema_version: 3,
  name: "stone gargoyle",
  noun: "gargoyle",
  url: "https://gswiki.play.net/stone_gargoyle",
  picture: "",
  level: 39,
  family: "Gargoyle",
  type: "Biped",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: 8,
  height: 16,
  size: "huge",
  areas: [
    {
      name: "Darkstone Castle",
      uids: [45150..45163]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (134..242)
      },
      {
        name: "Claw",
        as: 242
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (30..131),
    ranged: (18..131),
    bolt: (18..131),
    udf: (178..228),
    bar_td: nil,
    cle_td: 138,
    emp_td: 138,
    pal_td: (114..117),
    ran_td: 117,
    sor_td: 145,
    wiz_td: nil,
    mje_td: 153,
    mne_td: 153,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 117,
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
    boxes: true,
    skin: nil,
    other: [
      "Essence of earth",
      "crystal core",
      "glimmering blue essence dust"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The stone gargoyle, an animated being, was once a huge, grey, granite carving that overlooked the castle walls. Standing over fifteen feet tall on its powerful hind legs, the stone gargoyle was sculpted with a body similar to a lion's and a head that is a grotesque union between a human and a bat. Long horns protrude from the forehead and needle-like fangs extend menacingly below the upper lip. Swirling, yellow-green eyes, the only non-rock portion of the beast's anatomy, coldly examine the surrounding area."
    ],
    arrival: [
      "A stone gargoyle just arrived."
    ],
    flee: [
      "A stone gargoyle heads {direction}.",
      "A stone gargoyle limps {direction}."
    ],
    death: [
      "The stone gargoyle falls to the ground dead, {pronoun} stone hide still pulsating with a blinding white hue."
    ],
    decay: [
      "A stone gargoyle crumbles to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A stone gargoyle leaps at you with amazing speed and accuracy."
      ],
      bite: [
        "A stone gargoyle tries to bite you!"
      ],
      claw: [
        "A stone gargoyle claws at you!"
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
