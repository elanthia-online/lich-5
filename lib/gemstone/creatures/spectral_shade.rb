{
  schema_version: 3,
  name: "spectral shade",
  noun: "shade",
  url: "https://gswiki.play.net/spectral_shade",
  picture: "",
  level: 35,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 238,
  speed: 8,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4214303..4214323]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Blackened scythe",
        as: 239
      },
      {
        name: "Powerful lightning bolt",
        as: 162
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
    melee: (146..301),
    ranged: (126..180),
    bolt: (126..180),
    udf: (289..324),
    bar_td: nil,
    cle_td: (129..137),
    emp_td: (136..145),
    pal_td: (105..112),
    ran_td: (109..117),
    sor_td: (145..151),
    wiz_td: nil,
    mje_td: 155,
    mne_td: 155,
    mjs_td: (129..136),
    mns_td: (129..136),
    mnm_td: (104..113),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened scythe",
    "a bruised left eye",
    "some tattered rags"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The spectral shade is a mere shadow of a creature most of the time, yet it can resolve itself into immediate solidity when on the attack. Possessed of both potent physical and magical attacks, the spectral shade calls upon its many offensive capabilities to strike the living whenever possible. The spectral shade is best hunted in the daytime, as it blends easily into the darkness of night."
    ],
    arrival: [],
    flee: [
      "A spectral shade floats {direction}."
    ],
    death: [
      "A spectral shade fades into oblivion."
    ],
    decay: [
      "A spectral shade fades into oblivion."
    ],
    search: [],
    spell_prep: [
      "A spectral shade utters a phrase of arcane magic."
    ],
    attacks: {
      attack: [
        "A spectral shade nods at you!",
        "A spectral shade swings {weapon} at you!",
        "A spectral shade swings a blackened scythe at {target}!"
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
