{
  schema_version: 3,
  name: "death dirge",
  noun: "",
  url: "https://gswiki.play.net/death_dirge",
  picture: "",
  level: 9,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 95,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Plains of Bone",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 98
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 53
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: 14,
    ranged: nil,
    bolt: 17,
    udf: 66,
    bar_td: 27,
    cle_td: 27,
    emp_td: 27,
    pal_td: 27,
    ran_td: 27,
    sor_td: 27,
    wiz_td: 27,
    mje_td: 27,
    mne_td: 27,
    mjs_td: 27,
    mns_td: 27,
    mnm_td: 27,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a dirge skin",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Defender of a battleground long lost in the terrain, the death dirge still maintains its post relentlessly, battling all that would attempt to invade its position.  All that seems to remain in its consciousness are the orders to repel all who enter, a task it executes with single-minded fury.</pre>"
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
