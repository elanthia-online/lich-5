{
  schema_version: 3,
  name: "neartofar troll",
  noun: "troll",
  url: "https://gswiki.play.net/neartofar_troll",
  picture: "",
  level: 15,
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
  max_hp: 200,
  speed: 14,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015001..14015020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 179
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
    asg: "10",
    immunities: [],
    melee: (54..92),
    ranged: (42..92),
    bolt: (42..92),
    udf: 112,
    bar_td: 52,
    cle_td: 60,
    emp_td: 60,
    pal_td: (57..60),
    ran_td: 60,
    sor_td: 56,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 60,
    mns_td: 60,
    mnm_td: (45..52),
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
    "a longsword",
    "some weathered cuirbouilli leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a greasy troll scalp",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the Neartofar troll towers above even a tall giantman. Brown and green pigmented skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence."
    ],
    arrival: [
      "A Neartofar troll just arrived!",
      "A Neartofar orc stalks in purposefully, {pronoun} nose raised as {pronoun} sniffs at the air."
    ],
    flee: [
      "A Neartofar troll heads {direction}."
    ],
    death: [
      "The Neartofar troll falls to the ground and dies.",
      "The Neartofar troll screams one last time and dies.",
      "A Neartofar orc breathes {pronoun} last gasp and dies."
    ],
    decay: [
      "A Neartofar troll decays into compost."
    ],
    search: [
      "A Neartofar troll sniffs around looking for something."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A Neartofar troll swings {weapon} at you!",
        "A Neartofar troll throws {pronoun} head back and howls!",
        "A neartofar troll swings a longsword at you!",
        "A neartofar troll throws {pronoun} head back and howls!"
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
