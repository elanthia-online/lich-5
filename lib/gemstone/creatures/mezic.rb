{
  schema_version: 3,
  name: "mezic",
  noun: "mezic",
  url: "https://gswiki.play.net/mezic",
  picture: "",
  level: 33,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 240,
  speed: 9,
  height: 4,
  size: "small",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4214303..4214323]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain"
      },
      {
        name: "Stream of water",
        as: 198
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 236
      },
      {
        name: "Minor Fire (906)",
        as: 220
      },
      {
        name: "Minor Shock (901)",
        as: 236
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 180
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (209..305),
    ranged: (214..237),
    bolt: (214..237),
    udf: (209..290),
    bar_td: 110,
    cle_td: (99..114),
    emp_td: (111..117),
    pal_td: (92..102),
    ran_td: (103..113),
    sor_td: (113..132),
    wiz_td: nil,
    mje_td: (124..130),
    mne_td: (124..130),
    mjs_td: 134,
    mns_td: 134,
    mnm_td: (105..113),
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Focus (513)",
      "Mass Blur (911)",
      "Thurfel's Ward (503)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a ball",
    "some tattered rags",
    "a ball and chain"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Hunched shoulders and a stooping posture, the mezic is humanoid in appearance, her clothes ill-fitting and made of simple cloth. Dark, beady eyes stare at you from beneath a mass of tangled grey hair as the mezic shuffles her hunched form back and forth. Its long, gnarled fingers contort in magical configurations as it glances maliciously about the area."
    ],
    arrival: [],
    flee: [
      "A mezic hobbles {direction}.",
      "A mezic hobbles {direction}, grumbling about something or another.",
      "A mezic hobbles slowly {direction}."
    ],
    death: [
      "The mezic twitches violently, then dies.",
      "The mezic falls to the ground motionless.",
      "The mezic cries out one last time and lies still."
    ],
    decay: [
      "A mezic decays away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A mezic swings a ball and chain at {target}!"
      ],
      hurl: [
        "A mezic hurls {weapon} at you!"
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
