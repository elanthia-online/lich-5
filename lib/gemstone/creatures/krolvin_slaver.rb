{
  schema_version: 3,
  name: "krolvin slaver",
  noun: "slaver",
  url: "https://gswiki.play.net/krolvin_slaver",
  picture: "",
  level: 36,
  family: "Krolvin",
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
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Shattered Moors",
      uids: [420501..420542]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: (212..230)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)"
      },
      {
        name: "Silence (210)"
      }
    ],
    offensive_spells: [
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Tremors (909)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (140..250),
    ranged: (144..165),
    bolt: (144..165),
    udf: (235..303),
    bar_td: (99..117),
    cle_td: (108..117),
    emp_td: (108..117),
    pal_td: (96..108),
    ran_td: (99..108),
    sor_td: (99..117),
    wiz_td: nil,
    mje_td: (104..123),
    mne_td: (104..123),
    mjs_td: (99..117),
    mns_td: (99..117),
    mnm_td: (108..114),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a length of spiked chain",
    "a plain steel scimitar",
    "some double chain armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Although taller than the average krolvin, the slaver retains the characteristic long-fingered hands. His sturdy musculature is apparent beneath the grey-blue skin. Thick, coarse, white hair covers his head and spreads across his shoulders and down his back."
    ],
    arrival: [
      "A krolvin slaver just came through an oaken hatchway."
    ],
    flee: [
      "A krolvin slaver slinks {direction}.",
      "A krolvin slaver just went through an oaken hatchway.",
      "A krolvin slaver just went through a starboard door.",
      "A krolvin slaver holds {pronoun} hands out in front of him as {pronoun} slowly backs away."
    ],
    death: [
      "The krolvin slaver's body goes stiff and cold as he dies.",
      "A krolvin slaver collapses into a pile of dirty rags."
    ],
    decay: [
      "A krolvin slaver collapses into a pile of dirty rags."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A krolvin slaver's features turn to a blackened scowl as {pronoun} struggles to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A krolvin slaver swings {weapon} at you!",
        "A krolvin slaver growls a curse and gestures at you!"
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
