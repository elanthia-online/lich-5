{
  schema_version: 3,
  name: "greater ice spider",
  noun: "spider",
  url: "https://gswiki.play.net/greater_ice_spider",
  picture: "",
  level: 3,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 44,
  speed: nil,
  height: 2,
  size: "small",
  areas: [
    {
      name: "Southern Snowfields",
      uids: [4128045..4128055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: 48
      },
      {
        name: "Stinger (attack)",
        as: 71
      },
      {
        name: "Pincer",
        as: 54
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Webbed"
      }
    ],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (12..91),
    ranged: (13..31),
    bolt: (13..31),
    udf: (56..121),
    bar_td: nil,
    cle_td: 9,
    emp_td: 9,
    pal_td: (6..9),
    ran_td: 9,
    sor_td: 9,
    wiz_td: nil,
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a spider leg",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Often first noticed as just a large clump of moving snow, the greater ice spider resolves into a wide, low-slung spider three feet across and half again as long. Covered with thick, white hair to ward against the cold wind, the greater ice spider roams the snowfields looking for anything living it can web and consume."
    ],
    arrival: [],
    flee: [
      "A greater ice spider scurries {direction}."
    ],
    death: [
      "The greater ice spider collapses to the ground and dies.",
      "The greater ice spider's body jerks one last time and dies."
    ],
    decay: [
      "A greater ice spider's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greater ice spider snaps at you with {pronoun} pincer!"
      ],
      bite: [
        "A greater ice spider snaps at you with {pronoun} pincer!"
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
