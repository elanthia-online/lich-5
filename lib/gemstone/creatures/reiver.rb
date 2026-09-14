{
  schema_version: 3,
  name: "reiver",
  noun: "reiver",
  url: "https://gswiki.play.net/reiver",
  picture: "",
  level: 24,
  family: "Reiver",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 270,
  speed: 12,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Luinne Bheinn",
      uids: [4251011..4251013, 4251015..4251056]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 222
      },
      {
        name: "Handaxe",
        as: 222
      },
      {
        name: "Falchion",
        as: 222
      },
      {
        name: "Spear",
        as: 222
      },
      {
        name: "Two-handed sword",
        as: 222
      },
      {
        name: "Fist",
        as: 202
      },
      {
        name: "Unknown",
        as: 222
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
    asg: "various",
    immunities: [],
    melee: (92..144),
    ranged: (47..118),
    bolt: (47..118),
    udf: (151..155),
    bar_td: 72,
    cle_td: 72,
    emp_td: 72,
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 72,
    wiz_td: nil,
    mje_td: 72,
    mne_td: 72,
    mjs_td: (72..97),
    mns_td: (72..97),
    mnm_td: 72,
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
    "a falchion",
    "a gleaming chain hauberk",
    "a handaxe",
    "a reinforced shield",
    "a threadbare green tartan cloak",
    "a threadbare tartan cloak",
    "a wooden shield",
    "some augmented chain",
    "some double chain",
    "some half plate",
    "some steel leg greaves"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "glimmering blue essence shard",
      "s'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "The reiver struggles in vain to shake off the magic."
    ],
    attacks: {
      attack: [
        "A reiver pounds at you with {pronoun} fist!",
        "A reiver swings {weapon} at you!",
        "A reiver swings a broadsword at {target}!",
        "A reiver swings a handaxe at {target}!"
      ]
    },
    stand: [
      "A reiver stands up and dusts {reflexive} off."
    ],
    description: [
      "The reiver stands tall and proud. Moss-green eyes dominate the strong face and tousled, dark hair crowns the head. The reiver is well-muscled and toned, with calloused hands used to the wielding of weapons. Forged by a hard history and a harsh climate, the reiver is a tough fighter with a sense of honor and duty. Normally calm and amiable, the reiver's visage is thunderous when kith and kin are threatened or there are krolvins lurking."
    ],
    arrival: [
      "A reiver just arrived.",
      "A reiver just arrived, limping.",
      "A reiver just came through a red door."
    ],
    flee: [
      "A reiver heads {direction}.",
      "A reiver limps {direction}.",
      "A reiver just went through a red door."
    ],
    death: [
      "The reiver takes one last breath, then dies.",
      "The reiver falls to the ground motionless."
    ],
    decay: [
      "A reiver turns to dust."
    ],
    search: [
      "The reiver looks around a bit."
    ],
    spell_prep: [],
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
