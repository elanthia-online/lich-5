{
  schema_version: 3,
  name: "krynch",
  noun: "",
  url: "https://gswiki.play.net/krynch",
  picture: "",
  level: 31,
  family: "Krynch",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Mraent Caverns",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: (240..262)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tremors"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: 92,
    ranged: nil,
    bolt: 98,
    udf: nil,
    bar_td: (87..102),
    cle_td: 98,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: "106 124",
    mne_td: "106 124",
    mjs_td: 99,
    mns_td: 99,
    mnm_td: 93,
    defensive_spells: [
      "Natural Colors (601)"
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
    skin: "a krynch shinbone",
    other: nil
  },
  messaging: {
    description: [
      "Flecked with bits of mica and quartz crystal, the krynch shimmers in even the dimmest light. Moving with a fluid grace that belies the granite composition of its body, the creature has a barrel chest and thick, powerful limbs. The krynch has no visible ears or nose on its perfectly spherical head. Its mouth is fixed in a perpetual scowl and its glossy black eyes glare at you with malevolent intensity."
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
