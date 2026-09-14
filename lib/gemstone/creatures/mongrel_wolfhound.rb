{
  schema_version: 3,
  name: "mongrel wolfhound",
  noun: "wolfhound",
  url: "https://gswiki.play.net/mongrel_wolfhound",
  picture: "",
  level: 16,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: nil,
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
  max_hp: 150,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13034301..13034309, 13034314..13034337]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (132..150)
      },
      {
        name: "Charge",
        as: 161
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (102..150),
    ranged: (102..105),
    bolt: (102..105),
    udf: 166,
    bar_td: (42..48),
    cle_td: 42,
    emp_td: (29..48),
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 51,
    mjs_td: 48,
    mns_td: 48,
    mnm_td: (47..54),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a yellowed canine",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The large canine is obviously closely related to her domestic cousins, but her vicious growl and the feral gleam in her intelligent eyes speak of her far wilder nature. Ticks and burs speckle her matted, dusty fur, and her wolflike tail sweeps from side to side as she prepares to spring on her intended prey."
    ],
    arrival: [
      "A mongrel wolfhound bounds in howling at the top of {pronoun} voice."
    ],
    flee: [
      "A black mongrel wolfhound dashes {direction}.",
      "A mongrel wolfhound dashes {direction}."
    ],
    death: [
      "The mongrel wolfhound falls to the ground and dies.",
      "The black mongrel wolfhound falls to the ground and dies.",
      "The black mongrel wolfhound rolls over and dies.",
      "The mongrel wolfhound rolls over and dies."
    ],
    decay: [
      "A mongrel wolfhound decays into a pile of matted fur.",
      "A black mongrel wolfhound decays into a pile of matted fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A mongrel wolfhound shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A mongrel wolfhound charges at you!"
      ],
      bite: [
        "A mongrel wolfhound tries to bite you!"
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
