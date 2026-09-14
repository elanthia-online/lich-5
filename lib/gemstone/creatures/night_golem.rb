{
  schema_version: 3,
  name: "night golem",
  noun: "golem",
  url: "https://gswiki.play.net/night_golem",
  picture: "",
  level: 5,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 65,
  speed: 10,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "The Citadel",
      uids: [2102022..2102039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 96
      },
      {
        name: "Pound",
        as: 86
      },
      {
        name: "Black fists",
        as: 77
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
    asg: "12N",
    immunities: [],
    melee: (0..106),
    ranged: (0..11),
    bolt: (0..11),
    udf: (40..117),
    bar_td: nil,
    cle_td: 15,
    emp_td: nil,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 15,
    mns_td: 15,
    mnm_td: 15,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "night golem finger",
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Formed by the alchemists of the Citadel in their service to the Council of Twelve, these 4' tall golems appear to be made of coalesced night sky. Looking closely, you can see stars twinkling within their short, massive bodies."
    ],
    arrival: [],
    flee: [
      "A night golem lopes {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A night golem pounds at you with {pronoun} black fists!",
        "A night golem tries to ensnare you in {pronoun} black arms!",
        "A night golem pounds at {target} with {pronoun} black fists!",
        "A night golem tries to ensnare {target} in {pronoun} black arms!"
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
