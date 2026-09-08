{
  schema_version: 3,
  name: "giant hawk-owl",
  noun: "hawk-owl",
  url: "https://gswiki.play.net/giant_hawk-owl",
  picture: "",
  level: 28,
  family: "Bird",
  type: "Avian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 242,
  speed: 7,
  height: nil,
  size: "large",
  areas: [
    {
      name: "Sorcerer's Isle",
      uids: [14202001..14202023]
    },
    {
      name: "Teorainn Dale",
      uids: [13024035..13024064]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: 247
      },
      {
        name: "Bite",
        as: 247
      },
      {
        name: "Claw",
        as: (203..247)
      },
      {
        name: "Swoop",
        as: 194
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (164..189),
    ranged: (98..166),
    bolt: (98..166),
    udf: (192..217),
    bar_td: (84..87),
    cle_td: (78..90),
    emp_td: (80..90),
    pal_td: (78..87),
    ran_td: (81..90),
    sor_td: (84..87),
    wiz_td: nil,
    mje_td: (87..97),
    mne_td: (87..97),
    mjs_td: (78..90),
    mns_td: (78..90),
    mnm_td: (78..87),
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
    skin: "a tufted hawk-owl ear",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This large, stocky owl seems designed for predation. Its sharp talons are only partially concealed by its feathered legs, and the hawk-owl's beak is comparatively small, but razor sharp. Coal black eyes are set deep in the great bird's mottled facial disks."
    ],
    arrival: [],
    flee: [
      "A giant hawk-owl flies {direction}."
    ],
    death: [
      "The giant hawk-owl writhes in agony, its wings flapping fruitlessly as it dies.",
      "The giant hawk-owl crashes to the ground, motionless."
    ],
    decay: [
      "The giant hawk-owl decays into a pile of feathers."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A giant hawk-owl rakes at you with a razor-sharp claw!"
      ],
      claw: [
        "A giant hawk-owl rakes at {target} with a razor-sharp claw!"
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
