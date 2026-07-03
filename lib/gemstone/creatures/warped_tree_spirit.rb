{
  schema_version: 3,
  name: "warped tree spirit",
  noun: "",
  url: "https://gswiki.play.net/warped_tree_spirit",
  picture: "",
  level: 68,
  family: "Tree",
  type: "Plantlife",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 370,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Red Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Fear",
        cs: 307
      },
      {
        name: "Pain (711)",
        cs: 313
      }
    ],
    offensive_spells: [
      {
        name: "Earthen Fury (917)"
      },
      {
        name: "Powersink (1203)"
      }
    ],
    maneuvers: [
      {
        name: "Vine fling"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (250..284),
    ranged: 180,
    bolt: 174,
    udf: nil,
    bar_td: (230..242),
    cle_td: 261,
    emp_td: 257,
    pal_td: nil,
    ran_td: nil,
    sor_td: (249..261),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>\nThe undead tree spirit resides among its living brethren, barely distinguishable from them until it is awakened from its slumber.  Once awakened, terrible gashes and scars appear across its trunk, many of which would have been entirely fatal in life.  Its outline is not quite defined and its appearance shifts noticeably as it moves.  The occasional flicker reveals a horrifically malformed visage, before fading back to its normal tree-like state.\n</pre>"
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
