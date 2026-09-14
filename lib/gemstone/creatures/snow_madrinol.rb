{
  schema_version: 3,
  name: "snow madrinol",
  noun: "madrinol",
  url: "https://gswiki.play.net/snow_madrinol",
  picture: "",
  level: 52,
  family: "Madrinol",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: nil,
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
  max_hp: 260,
  speed: 8,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "Gossamer Valley",
      uids: [13023013..13023054, 13023076..13023076]
    },
    {
      name: "unmapped",
      uids: [13023055..13023075]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (291..301)
      },
      {
        name: "Claw",
        as: 311
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tail Sweep"
      },
      {
        name: "Tail Swipe"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "15N",
    immunities: [],
    melee: (229..472),
    ranged: (173..267),
    bolt: (173..267),
    udf: (266..337),
    bar_td: 177,
    cle_td: (199..205),
    emp_td: (191..194),
    pal_td: (173..176),
    ran_td: 176,
    sor_td: (203..212),
    wiz_td: nil,
    mje_td: (222..224),
    mne_td: (222..224),
    mjs_td: (188..208),
    mns_td: (188..208),
    mnm_td: (156..165),
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a madrinol skin",
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The heavily armored snow madrinol moves ponderously through the area searching for easy prey to consume. Plates of extremely thick slate grey skin cover this quadruped on nearly all its exterior surfaces except its long, leathery tail and cupped, upright ears. Tufts of off-white fur protrude between the plates, however, giving the impression that the madrinol is wearing pieces of armor rather than a total covering. Unique to the snow madrinol seems to be its flared, circular hooves. Sharp claws protrude from all sides of each hoof, allowing the creature to grip the ice or frozen ground for greater stability."
    ],
    arrival: [
      "A snow madrinol lumbers in pushing a fetid unwashed odor before it!",
      "A snow madrinol lumbers in, grumbling in pain."
    ],
    flee: [
      "A snow madrinol lumbers {direction}, grumbling in pain.",
      "A snow madrinol rumbles {direction}."
    ],
    death: [
      "The snow madrinol flips onto its back, kicks several times and dies.",
      "The snow madrinol rolls over onto its back, kicks several times and dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A snow madrinol charges towards a fellow snow madrinol and the two meet head first, sending both staggering."
      ],
      bite: [
        "A snow madrinol tries to bite you!"
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
