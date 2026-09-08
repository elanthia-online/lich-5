{
  schema_version: 3,
  name: "cave troll",
  noun: "troll",
  url: "https://gswiki.play.net/cave_troll",
  picture: "",
  level: 16,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 150,
  speed: 16,
  height: 10,
  size: "medium",
  areas: [
    {
      name: "Hidden Vale",
      uids: [36001..36005]
    },
    {
      name: "Vornavian Coast",
      uids: [4202161..4202180]
    },
    {
      name: "Upper Trollfang",
      uids: [14032..14043, 14052..14060, 17020..17028, 17101..17115]
    },
    {
      name: "Crystal Caves",
      uids: [24019..24057]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 191
      },
      {
        name: "Spear",
        as: 191
      },
      {
        name: "Pitted battle axe",
        as: 191
      },
      {
        name: "Unknown",
        as: 191
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
    melee: (84..105),
    ranged: (75..121),
    bolt: (75..121),
    udf: (102..121),
    bar_td: nil,
    cle_td: 63,
    emp_td: 63,
    pal_td: (60..63),
    ran_td: 63,
    sor_td: 59,
    wiz_td: nil,
    mje_td: (55..63),
    mne_td: (55..63),
    mjs_td: 63,
    mns_td: 63,
    mnm_td: (48..55),
    defensive_spells: [
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
    "a short sword",
    "a spear",
    "a war hammer",
    "a wooden shield",
    "some double leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll skin",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the cave troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence."
    ],
    arrival: [],
    flee: [
      "A cave troll lumbers {direction}."
    ],
    death: [
      "The cave troll falls to the ground and dies.",
      "The cave troll screams one last time and dies."
    ],
    decay: [
      "A cave troll decays into compost."
    ],
    search: [
      "A cave troll peers around suspiciously."
    ],
    spell_prep: [
      "A cave troll mutters, \"Trar'rt trast ar karm larlorirw slorlurarbr our'r.\"",
      "A cave troll mutters, \"Sr'r'wr'ralars 'ght lorlur'ra larlor'rikr.\""
    ],
    attacks: {
      attack: [
        "A cave troll swings {weapon} at you!",
        "A cave troll thrusts with a spear at you!",
        "A cave troll throws {pronoun} head back and howls!"
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
