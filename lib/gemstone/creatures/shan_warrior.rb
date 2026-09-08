{
  schema_version: 3,
  name: "shan warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/shan_warrior",
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
  max_hp: 300,
  speed: 7,
  height: 6,
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
        name: "Flamberge",
        as: (259..271)
      },
      {
        name: "Longsword",
        as: (231..259)
      },
      {
        name: "Jeddart-axe",
        as: (237..259)
      },
      {
        name: "Sharply-honed vultite handaxe",
        as: 375
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Disarm"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "see other info",
    immunities: [],
    melee: (154..349),
    ranged: (182..285),
    bolt: (182..285),
    udf: 407,
    bar_td: (117..150),
    cle_td: (120..132),
    emp_td: (123..132),
    pal_td: (126..135),
    ran_td: (126..135),
    sor_td: (117..135),
    wiz_td: nil,
    mje_td: (129..132),
    mne_td: (129..132),
    mjs_td: (150..159),
    mns_td: (150..159),
    mnm_td: (123..132),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dented chain hauberk",
    "a gleaming silver flamberge",
    "a gleaming silver longsword",
    "a plumed helm",
    "a spiked tower shield",
    "a visored helm",
    "a winged helm",
    "an over-sized jeddart-axe",
    "some nicked double chainmail",
    "some polished full platemail"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The shan warrior stands in a half-crouch, her long, knotty legs giving her that lanky, dangerous look of a wolf. Walking upright, the body covered with mottled grey fur and her long arms conclude in large, clawed hands with semi-opposable thumbs. The shan warrior's dog-like visage is fierce, with slavering jaws and eyes that glow like something out of a bad dream."
    ],
    arrival: [],
    flee: [
      "A shan warrior pads {direction}.",
      "A shan warrior limps {direction}.",
      "A shan warrior whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The shan warrior howls out one last time and dies.",
      "The shan warrior yips in pain as {pronoun} falls to the ground motionless.",
      "A shan warrior's body shimmers slightly.  Suddenly, {pronoun} features cave in, falling grotesquely into a haunting visage of decay, before abruptly fraying to a pile of fur and fangs that marks the spot of {pronoun} death like a silhouette."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A shan warrior swings {weapon} at you!",
        "A shan warrior swings a gleaming silver flamberge at {target}!",
        "A shan warrior swings an over-sized jeddart-axe at {target}!",
        "A shan warrior swings a gleaming silver longsword at {target}!",
        "A shan warrior swings {pronoun} long tail restlessly behind {pronoun}, pausing to study something on the far-horizon.",
        "A shan warrior swings {pronoun} {weapon} at your vultite handaxe!",
        "A shan warrior swings a sharply-honed vultite handaxe at {target}!",
        "A shan warrior rushes toward you, stopping abruptly in an attitude of intimidation with claws extended. Its eyes are arresting, glaring at you with sparks of red hatred in their depths..."
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
