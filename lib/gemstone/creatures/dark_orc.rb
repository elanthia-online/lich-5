{
  schema_version: 3,
  name: "dark orc",
  noun: "orc",
  url: "https://gswiki.play.net/dark_orc",
  picture: "",
  level: 12,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 150,
  speed: 12,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005054..14005066]
    },
    {
      name: "unmapped",
      uids: [21025..21028]
    },
    {
      name: "Smuggling Tunnels",
      uids: [37002..37021]
    },
    {
      name: "Vornavian Coast",
      uids: [4202401..4202416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: (147..157)
      },
      {
        name: "Scimitar",
        as: 157
      },
      {
        name: "Morning star",
        as: 157
      },
      {
        name: "Falchion",
        as: 157
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
    asg: "14",
    immunities: [],
    melee: (69..157),
    ranged: (26..70),
    bolt: (26..70),
    udf: (108..192),
    bar_td: 36,
    cle_td: 36,
    emp_td: (32..36),
    pal_td: nil,
    ran_td: 36,
    sor_td: (33..42),
    wiz_td: nil,
    mje_td: (33..36),
    mne_td: (33..36),
    mjs_td: (36..42),
    mns_td: (36..42),
    mnm_td: (36..39),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crudely forged iron halberd",
    "a dented iron helm",
    "a falchion",
    "a wooden shield",
    "some augmented chain",
    "some wide-ring double chain"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc ear",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dark orc obtains her name not from having dark coloration, but from her proclivity for seeking out dark places in which to live. In fact, the dark orc's body is covered by a fine layer of salt-and-pepper fur, with a preponderance of the lighter shade. Thick of skull and lacking good reasoning ability, the dark orc subsists on whatever creatures are foolish enough to find their way into her line of sight with no real concern as to how tough to kill or dangerous they might be."
    ],
    arrival: [],
    flee: [
      "A dark orc rambles {direction}.",
      "A dark orc grunts in pain and runs {direction}."
    ],
    death: [
      "A dark orc gives a last shudder and dies."
    ],
    decay: [
      "A small, green cloud of smelly gas rises from the body of a mongrel kobold as he decays into compost.",
      "A small, green cloud of smelly gas rises from the body of a big ugly kobold as she decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A dark orc swings {weapon} at you!"
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
