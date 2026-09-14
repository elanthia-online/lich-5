{
  schema_version: 3,
  name: "greater ghoul",
  noun: "ghoul",
  url: "https://gswiki.play.net/greater_ghoul",
  picture: "",
  level: 3,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 60,
  speed: 15,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008025..14008051]
    },
    {
      name: "The Citadel",
      uids: [2102008..2102020]
    },
    {
      name: "The Graveyard",
      uids: [18048..18058, 18060..18061, 18065..18068, 2162001..2162015]
    },
    {
      name: "Vornavian Coast",
      uids: [4202141..4202156]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 63
      },
      {
        name: "Unknown",
        as: 63
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
    asg: "1N",
    immunities: [],
    melee: (0..69),
    ranged: (7..8),
    bolt: (7..8),
    udf: (46..51),
    bar_td: 9,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: 9,
    mje_td: 9,
    mne_td: 9,
    mjs_td: 9,
    mns_td: 9,
    mnm_td: 9,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a short sword",
    "some dry-rotted rags"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a ghoul scraping",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Larger and meaner then its lesser brethren, the greater ghoul shambles along with filth-encrusted claws and ragged bits of decaying flesh hanging from sharp fangs in its decaying jaws. A few filthy bits of rotting cloth still cling to its diseased and festering body as it wanders dimly in search of more flesh."
    ],
    arrival: [
      "A greater ghoul just arrived!",
      "A greater ghoul just arrived.",
      "A greater ghoul just arrived, limping badly."
    ],
    flee: [
      "A greater ghoul runs {direction}."
    ],
    death: [
      "The greater ghoul falls to the ground motionless.",
      "The greater ghoul screams evilly one last time and goes still."
    ],
    decay: [
      "A greater ghoul turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater ghoul swings {weapon} at you!"
      ],
      claw: [
        "A greater ghoul claws at you!"
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
