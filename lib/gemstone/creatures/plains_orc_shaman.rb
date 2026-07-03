{
  schema_version: 3,
  name: "plains orc shaman",
  noun: "",
  url: "https://gswiki.play.net/plains_orc_shaman",
  picture: "",
  level: 18,
  family: "Orc",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Yegharren Plains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Kris",
        as: 164
      },
      {
        name: "Mace",
        as: 164
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid",
        as: 166
      },
      {
        name: "Major Fire",
        as: 166
      },
      {
        name: "Major Shock",
        as: 166
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: (66..76),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 78,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Thurfel's Ward",
      "Prismatic Guard",
      "Mass Blur"
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
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: "a scraggly orc scalp",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The plains orc shaman watches his surroundings diligently through shifting yellow eyes that hint at a cunning and dangerous intelligence.  His heavily-muscled limbs bear an almost runelike pattern of ritually inflicted scars, and his tangled red beard is adorned with crude bone and wood beads.  The shaman mutters to himself in a series of guttural incantations.</pre>"
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
