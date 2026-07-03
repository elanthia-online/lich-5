{
  schema_version: 3,
  name: "fenghai",
  noun: "",
  url: "https://gswiki.play.net/fenghai",
  picture: "",
  level: 23,
  family: "Fey",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 190,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "kris",
        as: 173
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 167
      },
      {
        name: "Major Cold (907)",
        as: (160..167)
      },
      {
        name: "Major Fire (908)",
        as: 178
      },
      {
        name: "Minor Shock (901)",
        as: 167
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: 122,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 76,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 94,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 83,
    mjs_td: nil,
    mns_td: 80,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Focus (513)",
      "Thurfel's Ward (503)",
      "Wizard's Shield (919)"
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
    skin: "a fenghai fur",
    other: "[[Glimmering blue essence shard]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The fenghai seems to be a furry little ball with feet.  Sparkling eyes peer out from a mop of russet fur, looking about with a happy curiousity.  Stubby arms end in pudgy little hands that appear dextrous despite their dimensions, and the round-toed feet are covered in hair and dirt.  While comical in appearance, it is obvious that the furball can take care of itself.</pre>"
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
