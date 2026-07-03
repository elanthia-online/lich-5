{
  schema_version: 3,
  name: "triton warden",
  noun: "",
  url: "https://gswiki.play.net/triton_warden",
  picture: "",
  level: 102,
  family: "Triton",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Atoll",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longbow",
        as: "411 to 446"
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Wild Entropy (603)",
        cs: 448
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Sunburst (609)"
      },
      {
        name: "Tangleweed (610)"
      },
      {
        name: "Spike Thorn (616)"
      },
      {
        name: "Stealth"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "433 to 471",
    wiz_td: nil,
    mje_td: nil,
    mne_td: 480,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Natural Colors (601)",
      "Resist Elements (602)",
      "Self Control (613)",
      "Sneaking (617)",
      "Nature's Touch (625)",
      "Wall of Thorns (640)"
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
    skin: "curved black claw",
    other: nil
  },
  messaging: {
    description: [
      "A faded coat of sun-bleached oilskin graces the muscular shoulders of a triton warden, the rusted ornamentations covered in grey-cast barnacles and dried kelp. His trident-branded knuckles are exposed through his desiccated leather gloves, the shreds of hide clinging tightly to his green-tinged forearms. The warden growls softly through his clenched teeth, the sharp protrusions biting down on a broken driftwood pipe."
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
