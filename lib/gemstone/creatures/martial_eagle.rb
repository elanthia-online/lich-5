{
  schema_version: 3,
  name: "martial eagle",
  noun: "eagle",
  url: "https://gswiki.play.net/martial_eagle",
  picture: "",
  level: 28,
  family: "Bird",
  type: "Avian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 330,
  speed: nil,
  height: 2,
  size: "large",
  areas: [
    {
      name: "Sorcerer's Isle",
      uids: [14202001..14202023]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 230
      },
      {
        name: "Claw",
        as: 230
      },
      {
        name: "Swoop",
        as: 220
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "9N",
    immunities: [],
    melee: (147..172),
    ranged: 139,
    bolt: nil,
    udf: (167..178),
    bar_td: nil,
    cle_td: nil,
    emp_td: (93..101),
    pal_td: (81..90),
    ran_td: nil,
    sor_td: 97,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 101,
    mjs_td: 93,
    mns_td: 93,
    mnm_td: (81..90),
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
    skin: "a martial eagle talon",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Larger than a typical halfling, this powerfully built raptor has glossy brown feathers over its wings, which extend for at least four feet to either side of its stocky body. Its head and upper chest are the same dark brown, making its golden eyes all the more dramatic. Its underparts are pale, streaked with black, matching its flight feathers. The majestic bird's powerful talons are well equipped to trap and maul prey."
    ],
    arrival: [],
    flee: [
      "A martial eagle flies {direction}."
    ],
    death: [
      "The martial eagle writhes in agony, its wings flapping fruitlessly as it dies.",
      "The martial eagle crashes to the ground, motionless."
    ],
    decay: [
      "The martial eagle decays into a pile of feathers."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A martial eagle strikes out at you with all of {pronoun} might!"
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
