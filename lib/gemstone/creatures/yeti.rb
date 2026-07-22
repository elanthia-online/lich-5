{
  schema_version: 3,
  name: "yeti",
  noun: "",
  url: "https://gswiki.play.net/yeti",
  picture: "",
  level: 67,
  family: "Yeti",
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
      name: "Griffin's Keen",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: (347..359)
      },
      {
        name: "Stomp",
        as: 347
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground Slap"
      },
      {
        name: "Hurl Boulder (510)"
      },
      {
        name: "Stomp"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 223,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (226..247),
    cle_td: nil,
    emp_td: 253,
    pal_td: nil,
    ran_td: nil,
    sor_td: 269,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 283,
    mjs_td: nil,
    mns_td: 253,
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
    other: nil
  },
  messaging: {
    description: [
      "Standing almost twelve feet tall, the yeti is a large humanoid creature covered in long, stringy black and red hair. His domed pate is matted with twigs and dirt, and his heavy brow forms a shelf over his tiny black eyes. With arms nearly long enough to brush the ground, the yeti has a ferociously strong grip and excellent leverage for the tossing of heavy objects. Broad, flat feet provide stability and traction in the icy, mountainous environments that are his normal habitat."
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
