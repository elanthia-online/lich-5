{
  schema_version: 3,
  name: "shan cleric",
  noun: "cleric",
  url: "https://gswiki.play.net/shan_cleric",
  picture: "",
  level: 42,
  family: "Shan",
  type: "Biped",
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
  max_hp: 238,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4218301..4218325]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: 212
      },
      {
        name: "Spiked holy-water sprinkler",
        as: 307
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 209
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Disarm"
      },
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (252..352),
    ranged: (247..275),
    bolt: (247..275),
    udf: 276,
    bar_td: (116..157),
    cle_td: (160..170),
    emp_td: (159..172),
    pal_td: (143..152),
    ran_td: (129..136),
    sor_td: (170..180),
    wiz_td: nil,
    mje_td: (177..182),
    mne_td: (177..182),
    mjs_td: (159..169),
    mns_td: (159..169),
    mnm_td: 172,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Prayer (313)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a small silver roundshield",
    "a spiked holy-water sprinkler",
    "some dark braided leathers"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Tiny golden seed",
      "glowing violet essence dust"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The shan cleric stands in a half-crouch, her long, knotty legs giving her that lanky, dangerous look of a wolf. Walking upright, the body covered with mottled grey fur and her long arms conclude in large, clawed hands with semi-opposable thumbs. The shan cleric's dog-like visage is fierce, with slavering jaws and eyes that glow like something out of a bad dream."
    ],
    arrival: [],
    flee: [
      "A shan cleric pads {direction}.",
      "A shan cleric limps {direction}."
    ],
    death: [
      "The shan cleric howls out one last time and dies.",
      "The shan cleric yips in pain as {pronoun} falls to the ground motionless.",
      "A shan cleric's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shan cleric swings {weapon} at you!",
        "A shan cleric swings a spiked holy-water sprinkler at {target}!",
        "A shan cleric waves a hand dismissively at you!"
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
