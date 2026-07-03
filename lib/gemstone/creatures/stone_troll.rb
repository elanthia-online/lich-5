{
  schema_version: 3,
  name: "stone troll",
  noun: "",
  url: "https://gswiki.play.net/stone_troll",
  picture: "",
  level: 55,
  family: "Troll",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Thrown",
        as: 321
      },
      {
        name: "War hammer",
        as: 321
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Unbalance",
        cs: 214
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Ground slap"
      },
      {
        name: "Ground stomp"
      },
      {
        name: "Stone spit"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (120..302),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (183..195),
    cle_td: 206,
    emp_td: nil,
    pal_td: 165,
    ran_td: nil,
    sor_td: 228,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 204,
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
    skin: nil,
    other: "small troll tooth, large troll tooth"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>\nTowering above you, the stone troll is an ugly, brutish looking creature.  Its marbled grey skin is covered with pocks and divots.  This lumpy grotesque troll grins maniacally at you, sending cracks and fissures across its face."
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
