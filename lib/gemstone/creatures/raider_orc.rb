{
  schema_version: 3,
  name: "raider orc",
  noun: "orc",
  url: "https://gswiki.play.net/raider_orc",
  picture: "",
  level: 10,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 131,
  speed: 10,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005038..14005053]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Twohanded sword",
        as: (122..132)
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
    asg: "17",
    immunities: [],
    melee: (51..134),
    ranged: (44..56),
    bolt: (46..56),
    udf: (107..189),
    bar_td: 30,
    cle_td: 30,
    emp_td: 30,
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 30,
    mjs_td: 30,
    mns_td: 30,
    mnm_td: 30,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a metal breastplate",
    "a ragged sack",
    "a twohanded sword"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A glimmer of intelligence actually resides behind the crimson eyes of the raider orc, unusual for a member of the orc species. He shares the same bony cranium and noxious odor of his brethren, but he strides much more upright, and his sharp teeth are only revealed when necessary for rending something. Interestingly, the raider orc's clawed fingers show webbing in between, indicating that this orc may be as much at home on bodies of water as he is on land."
    ],
    arrival: [
      "A raider orc saunters in looking for something to pillage."
    ],
    flee: [
      "A raider orc trots {direction}.",
      "A raider orc trots {direction}, {pronoun} gaze sweeping the area for danger."
    ],
    death: [
      "A raider orc screams {pronoun} defiance skyward one last time and dies.",
      "A raider orc screams {pronoun} defiance silently skyward one last time and dies."
    ],
    decay: [
      "A raider orc withers away until {pronoun} is no more."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A raider orc swings {weapon} at you!"
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
