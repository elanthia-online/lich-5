{
  schema_version: 3,
  name: "frenzied monk",
  noun: "",
  url: "https://gswiki.play.net/frenzied_monk",
  picture: "",
  level: 27,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 220,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Lunule Weald",
      rooms: []
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
    melee: 229,
    ranged: nil,
    bolt: 210,
    udf: nil,
    bar_td: (96..107),
    cle_td: 114,
    emp_td: nil,
    pal_td: nil,
    ran_td: 105,
    sor_td: 120,
    wiz_td: nil,
    mje_td: nil,
    mne_td: (115..126),
    mjs_td: nil,
    mns_td: 115,
    mnm_td: nil,
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
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "[[Glimmering blue essence shard]]<br>[[Glimmering blue mote of essence]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A muddy black cowl obscures the monk's face. Given the burning green eyes and foul stench he exudes, perhaps that is for the best.  Tattered black rags cloak his form, while the only marking visible on his ragged clothing is that of a haphazardly stitched crescent moon symbol.</pre>"
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
