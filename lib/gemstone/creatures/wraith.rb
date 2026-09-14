{
  schema_version: 3,
  name: "wraith",
  noun: "wraith",
  url: "https://gswiki.play.net/wraith",
  picture: "",
  level: 15,
  family: "Wraith",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 133,
  speed: 7,
  height: 7,
  size: "large",
  areas: [
    {
      name: "The Graveyard",
      uids: [2138123..2138142]
    },
    {
      name: "Smuggling Tunnels",
      uids: [37022..37041]
    },
    {
      name: "Abandoned Farm",
      uids: [4124007..4124013, 4124027..4124036]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 147
      },
      {
        name: "Handaxe",
        as: 147
      },
      {
        name: "Short sword",
        as: 147
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
    melee: (65..151),
    ranged: (65..78),
    bolt: (65..78),
    udf: (105..166),
    bar_td: nil,
    cle_td: 45,
    emp_td: 45,
    pal_td: (42..45),
    ran_td: 45,
    sor_td: 45,
    wiz_td: nil,
    mje_td: 45,
    mne_td: 45,
    mjs_td: 45,
    mns_td: 45,
    mnm_td: 45,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a handaxe",
    "a short sword",
    "some brigandine armor",
    "some double leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a wraith talon",
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A creature of darkness, the wraith shies away from the light, preferring to ambush and rend its prey in the safety of the deep shadows. Its crimson eyes glare hatefully at the world around it, while its tortured grimace displays sharp, gleaming fangs. Proficient with weaponry, a disarmed wraith is still a formidable foe, as its long, sharp talons indicate."
    ],
    arrival: [
      "A wraith just arrived."
    ],
    flee: [],
    death: [
      "The wraith falls to the ground motionless.",
      "The wraith screams evilly one last time and goes still.",
      "A troll wraith slumps to the ground, lying completely motionless.  A last minute twitch causes the wraith's arm to spasm up into the air before falling limply back to {pronoun} side."
    ],
    decay: [
      "A wraith turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A wraith gestures at you!",
        "A wraith swings {weapon} at you!"
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
    triggers: {},
    frenzy: "A wraith spins in a frenzy and a strong wind whips around you."
  }
}
