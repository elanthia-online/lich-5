{
  schema_version: 3,
  name: "large ring-tailed lemur",
  noun: "",
  url: "https://gswiki.play.net/large_ring-tailed_lemur",
  picture: "",
  level: 20,
  family: "Primate",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 190,
  speed: 8,
  height: nil,
  size: "",
  areas: [
    {
      name: "Monsoon Jungle",
      uids: [3218001..3218044, 3218049..3218054]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 118
      },
      {
        name: "Closed fist",
        as: 118
      },
      {
        name: "Bite",
        as: 111
      },
      {
        name: "Charge",
        as: 208
      },
      {
        name: "Sharp claws",
        as: 117
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
    asg: "8N",
    immunities: [],
    melee: (162..219),
    ranged: (105..136),
    bolt: (105..136),
    udf: (338..400),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (60..66),
    sor_td: 61,
    wiz_td: nil,
    mje_td: (62..63),
    mne_td: (62..63),
    mjs_td: nil,
    mns_td: 60,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Pickpocketing",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "lemur tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Tufts of white hair stand straight out from the ears and face of the ring-tail lemur before trailing down to cover his neck and abdomen. Black rings surround his eyes like a mask and short, black fur covers his pointed muzzle. Soft, fluffy brown fur covers the ring-tail lemur short body as well as his thin arms and legs. The lemur's long bushy tail has alternating bands of black and white rings that are capped with fuzz."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "Launching {pronoun} into the air, the jungle toad charges at you with {pronoun} enormous, flat head!",
        "Lunging forward, a large ring-tailed lemur swings {weapon} at you and attempts to slash you with {pronoun} sharp claws!"
      ],
      bite: [
        "A large ring-tailed lemur attempts to bite you!"
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
