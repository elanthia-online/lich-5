{
  schema_version: 3,
  name: "war troll",
  noun: "troll",
  url: "https://gswiki.play.net/war_troll",
  picture: "",
  level: 18,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 230,
  speed: 9,
  height: 10,
  size: "large",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [14001..14005, 14010..14020, 17102..17118]
    },
    {
      name: "Slope",
      uids: [395017..395051]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword"
      },
      {
        name: "War hammer",
        as: 175
      },
      {
        name: "Unknown",
        as: 211
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Attack strength boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (44..108),
    ranged: (35..53),
    bolt: (35..53),
    udf: (89..202),
    bar_td: nil,
    cle_td: 69,
    emp_td: 69,
    pal_td: (66..69),
    ran_td: 69,
    sor_td: 65,
    wiz_td: nil,
    mje_td: (54..69),
    mne_td: (54..69),
    mjs_td: 69,
    mns_td: 69,
    mnm_td: (54..61),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Health regeneration",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a chain hauberk",
    "a leather helm",
    "a twohanded sword",
    "a war hammer",
    "a wooden shield",
    "some studded leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll heart",
    other: "small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the war troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.\n\nAppraisal:\nThe war troll is large in size, about ten feet high in his current state, appears to be of hardy constitution, is in an offensive stance, and is in relatively good shape."
    ],
    arrival: [
      "A war troll pounds in!"
    ],
    flee: [
      "A war troll limps {direction}.",
      "A war troll pounds {direction}."
    ],
    death: [
      "The war troll falls to the ground and dies.",
      "The war troll screams one last time and dies."
    ],
    decay: [
      "A war troll decays into compost."
    ],
    search: [
      "A war troll sniffs around looking for something."
    ],
    spell_prep: [
      "A war troll mutters, \"'Nirf od larlorruo.\""
    ],
    attacks: {
      attack: [
        "A war troll swings {weapon} at you!",
        "A war troll throws {pronoun} head back and lets out a mighty war bellow!",
        "A war troll throws {pronoun} head back and howls!",
        "A war troll swings a war hammer at {target}!"
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
