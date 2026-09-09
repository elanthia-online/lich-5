{
  schema_version: 3,
  name: "bog wight",
  noun: "wight",
  url: "https://gswiki.play.net/bog_wight",
  picture: "",
  level: 44,
  family: "Wight",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Fethayl Bog",
      uids: [13038001..13038031]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (270..274)
      },
      {
        name: "Claw",
        as: (204..284)
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
    asg: "9",
    immunities: [],
    melee: (148..330),
    ranged: (157..244),
    bolt: (157..244),
    udf: (208..305),
    bar_td: (126..132),
    cle_td: (145..154),
    emp_td: (141..144),
    pal_td: (123..132),
    ran_td: (126..132),
    sor_td: (153..162),
    wiz_td: nil,
    mje_td: (153..163),
    mne_td: (153..163),
    mjs_td: (181..185),
    mns_td: (181..185),
    mnm_td: (132..141),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a ragged blackened breastplate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Cloaked in a thick shroud of mist that perpetually follows it, the bog wight moves with a quick grace. Two burning red orbs stare out from its gaunt, emaciated face, devoid of any compassion or mercy. A fanged, lipless mouth accompanies its haunting eyes, the maggot-white skin of its face pulled so taught over its skull that it gives the impression of a bestial grin. Wisps of the miasma that enshrouds its nearly skeletal form whipback and forth as it glides about, writhing against its tattered robes."
    ],
    arrival: [
      "A bog wight just arrived."
    ],
    flee: [
      "A bog wight rushes {direction}."
    ],
    death: [
      "The bog wight falls to the ground motionless.",
      "The bog wight wails in terrifying pain one last time and lies still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "A bog wight claws at you!"
      ],
      bite: [
        "A bog wight tries to bite you!"
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
