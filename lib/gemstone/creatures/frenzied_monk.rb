{
  schema_version: 3,
  name: "frenzied monk",
  noun: "monk",
  url: "https://gswiki.play.net/frenzied_monk",
  picture: "",
  level: 27,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 220,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Lunule Weald",
      uids: [14016039..14016057, 14016059..14016082]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 174
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 150
      }
    ],
    offensive_spells: [
      {
        name: "Bravery (211)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (174..250),
    ranged: (140..182),
    bolt: (140..210),
    udf: (197..269),
    bar_td: (96..107),
    cle_td: 104,
    emp_td: (105..113),
    pal_td: (86..95),
    ran_td: (86..105),
    sor_td: (112..120),
    wiz_td: nil,
    mje_td: nil,
    mne_td: (115..126),
    mjs_td: (105..115),
    mns_td: (105..115),
    mnm_td: (75..84),
    defensive_spells: [
      "Prayer of Protection (303)",
      "Prismatic Guard (905)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Thurfel's Ward (503)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some moss-covered leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence shardGlimmering blue mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A muddy black cowl obscures the monk's face. Given the burning green eyes and foul stench he exudes, perhaps that is for the best. Tattered black rags cloak his form, while the only marking visible on his ragged clothing is that of a haphazardly stitched crescent moon symbol."
    ],
    arrival: [],
    flee: [
      "A frenzied monk seethes in pain as he limps {direction}."
    ],
    death: [],
    decay: [
      "A frenzied monk dissolves into a foul-smelling miasma.",
      "A nebulous frenzied monk dissolves into a foul-smelling miasma.",
      "An unyielding frenzied monk dissolves into a foul-smelling miasma.",
      "An adroit frenzied monk dissolves into a foul-smelling miasma.",
      "The frenzied monk seems to collapse in upon {reflexive}, leaving only a withered husk."
    ],
    search: [],
    spell_prep: [
      "A frenzied monk utters an arcane incantation."
    ],
    stun_break: [
      "A frenzied monk's eyes flash with a baleful green light as {pronoun} shakes off the stun!"
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
