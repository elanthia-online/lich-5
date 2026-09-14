{
  schema_version: 3,
  name: "crazed zombie",
  noun: "zombie",
  url: "https://gswiki.play.net/crazed_zombie",
  picture: "",
  level: 23,
  family: "Zombie",
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
  boss_type: "pack",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 262,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Lunule Weald",
      uids: [14016001..14016038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (181..202)
      },
      {
        name: "Claw",
        as: 202
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
    melee: (93..150),
    ranged: (91..132),
    bolt: (91..132),
    udf: (114..211),
    bar_td: 69,
    cle_td: (67..76),
    emp_td: (72..80),
    pal_td: (66..75),
    ran_td: nil,
    sor_td: (68..74),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (77..83),
    mjs_td: 100,
    mns_td: 100,
    mnm_td: (63..72),
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
    skin: "a zombie scalp",
    other: "Glimmering blue essence shardGlimmering blue mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Pity the poor crazed zombie, an animated corpse abandoned long ago by her creator. The skin of the crazed zombie has turned a sickly grey, her clothing hangs in tattered ribbons, and she barely keeps control over her death-stiffened muscles. Her mouth, once sewn shut to hold the salt necessary in the animation process, has broken open again, salt dribbling from the parched, thread-covered lips. The crazed zombie verbally threatens and attacks anyone she believes may interfere with her quest to return to the grave."
    ],
    arrival: [
      "A crazed zombie shambles in!",
      "A lustrous crazed zombie shambles in!",
      "A glittering crazed zombie shambles in!",
      "A luminous crazed zombie shambles in!",
      "A slimy crazed zombie shambles in!"
    ],
    flee: [
      "A crazed zombie shambles {direction}.",
      "A crazed zombie wails madly as she limps {direction}."
    ],
    death: [
      "The crazed zombie falls to the ground, a lifeless lump of flesh."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A crazed zombie lashes about the area unsteadily grasping at the air."
      ],
      bite: [
        "A crazed zombie tries to bite you!"
      ],
      claw: [
        "A crazed zombie claws at you!"
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
