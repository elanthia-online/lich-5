{
  schema_version: 3,
  name: "lava troll",
  noun: "",
  url: "https://gswiki.play.net/lava_troll",
  picture: "",
  level: 34,
  family: "Troll",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Maul",
        as: 215
      },
      {
        name: "Warsword",
        as: 215
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: 118,
    ranged: nil,
    bolt: 136,
    udf: nil,
    bar_td: (105..111),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 123,
    wiz_td: nil,
    mje_td: 135,
    mne_td: 129,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll eye",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Easily twice as large as the largest giantman, this brutish creature glares with coal black eyes.  The lava troll has reddened, blistered skin and soot-black hair.  Steam pours from her ears when she bares her blackened fangs.</pre>"
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
