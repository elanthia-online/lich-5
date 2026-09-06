{
  schema_version: 3,
  name: "cave gnome",
  noun: "gnome",
  url: "https://gswiki.play.net/cave_gnome",
  picture: "",
  level: 2,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 50,
  speed: 15,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Catacombs",
      uids: [46029..46033, 46035..46037]
    },
    {
      name: "Upper Dragonsclaw",
      uids: [2121015..2121024]
    },
    {
      name: "Subterranean Tunnels",
      uids: [4045120..4045141]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 52
      },
      {
        name: "Handaxe",
        as: 52
      },
      {
        name: "Short sword",
        as: (46..52)
      },
      {
        name: "Unknown",
        as: 52
      },
      {
        name: "Closed fist",
        as: 42
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
    melee: (0..94),
    ranged: (7..10),
    bolt: (7..10),
    udf: (37..61),
    bar_td: nil,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a handaxe",
    "a leather breastplate",
    "a reinforced shield",
    "a short sword",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a gnome scalp",
    other: [
      "Alchemy (common)",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This very short creature resembles, if anything, a misshapen dwarf. Whereas dwarves carry themselves upright, the cave gnome scampers about in a hunched over fashion, peering malignantly up at intruders through bulging purple eyes set on a head seemingly a few sizes too big for the associated body. Do not mistake their size as a limitation, though. The cave gnome regularly bounces high enough in combat to strike giantmen square in the head."
    ],
    arrival: [
      "A cave gnome just arrived.",
      "A cave gnome just arrived, limping.",
      "A cave gnome ambles in."
    ],
    flee: [
      "A cave gnome heads {direction}.",
      "A cave gnome limps {direction}."
    ],
    death: [
      "The cave gnome falls to the ground and dies.",
      "The cave gnome screams one last time and dies."
    ],
    decay: [
      "A cave gnome decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A cave gnome swings {weapon} at you!"
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
