{
  schema_version: 3,
  name: "major spider",
  noun: "spider",
  url: "https://gswiki.play.net/major_spider",
  picture: "",
  level: 20,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: 7,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Lower Trollfang",
      uids: [12001..12051]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 168
      },
      {
        name: "Ensnare",
        as: (178..186)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11N",
    immunities: [],
    melee: (60..227),
    ranged: (46..167),
    bolt: (46..167),
    udf: (73..225),
    bar_td: nil,
    cle_td: (57..66),
    emp_td: (57..66),
    pal_td: (54..63),
    ran_td: (57..66),
    sor_td: (55..61),
    wiz_td: nil,
    mje_td: (62..65),
    mne_td: (62..65),
    mjs_td: (60..73),
    mns_td: (60..73),
    mnm_td: (54..60),
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Large enough to encompass a horse in her grasp, the major spider needs no web to feed from though she uses her sticky traps well when it suits her. Agile and aggressive, this demon among spiders crouches before you, her unwinking eyes showing no emotion as she waits to attack or defend. The palps around her mouth work continuously and a thin line of digestive slime drools down her mandibles."
    ],
    arrival: [],
    flee: [
      "A major spider crawls {direction}.",
      "A major spider scurries {direction}.",
      "A major spider hobbles {direction}."
    ],
    death: [
      "The major spider collapses to the ground and dies.",
      "The major spider's body jerks one last time and dies."
    ],
    decay: [
      "A major spider's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A major spider tries to ensnare you!"
      ],
      bite: [
        "A major spider tries to bite you!"
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
