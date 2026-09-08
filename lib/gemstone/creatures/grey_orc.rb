{
  schema_version: 3,
  name: "grey orc",
  noun: "orc",
  url: "https://gswiki.play.net/grey_orc",
  picture: "",
  level: 14,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: nil,
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
  bcs: false,
  max_hp: 127,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005067..14005080]
    },
    {
      name: "Upper Trollfang",
      uids: [14015..14023, 14025..14025, 16051..16057]
    },
    {
      name: "unmapped",
      uids: [14024..14024]
    },
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250005..4250021]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Composite bow",
        as: 139
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 130
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Gas cloud"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (101..143),
    ranged: (47..105),
    bolt: (47..105),
    udf: (86..185),
    bar_td: 42,
    cle_td: (39..42),
    emp_td: (42..46),
    pal_td: (39..48),
    ran_td: (39..42),
    sor_td: (42..45),
    wiz_td: 42,
    mje_td: (42..45),
    mne_td: (42..45),
    mjs_td: 42,
    mns_td: 42,
    mnm_td: (42..45),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened composite bow",
    "a deerskin quiver",
    "a mace",
    "a metal aventail",
    "some double leather",
    "some studded urgh-hide leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc beard",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This orc, midway in size between a lesser and a greater orc, the grey orc has a greyish cast to its skin, lending an unhealthy pallor to an already hideous countenance. Dim intelligence flickers behind the narrow eyes and a mocking grin shows blackened and rotting teeth."
    ],
    arrival: [
      "A grey orc plods in and sniffs the air!"
    ],
    flee: [
      "A grey orc treks {direction}."
    ],
    death: [
      "A grey orc gazes upward one last time and dies."
    ],
    decay: [],
    search: [
      "A grey orc sniffs the air and then whirls around looking for something."
    ],
    spell_prep: [
      "A grey orc gestures into the air!",
      "A grey orc gestures skyward and grunts a hoarse phrase."
    ],
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
