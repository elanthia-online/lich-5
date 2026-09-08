{
  schema_version: 3,
  name: "sand beetle",
  noun: "beetle",
  url: "https://gswiki.play.net/sand_beetle",
  picture: "",
  level: 33,
  family: "Beetle",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 377,
  speed: nil,
  height: 2,
  size: "large",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4217201..4217216]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pincer (attack)",
        as: 232
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Gas cloud"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (75..190),
    ranged: (67..122),
    bolt: (67..122),
    udf: 180,
    bar_td: nil,
    cle_td: 102,
    emp_td: 103,
    pal_td: (87..90),
    ran_td: (96..99),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 114,
    mne_td: 114,
    mjs_td: 103,
    mns_td: 103,
    mnm_td: (96..99),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a beetle pincer",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The sand beetle appears to be some sort of giant insect. It looks a little like some misshapen scorpion, but the tail on it is not as long as a scorpion's would be, and it flares like the tail of a lobster rather than ending in a poison sting. The segmented body is wide, supported by six short multi-jointed legs. A dull red chitinous shell covers most of its body, and a broad carapace protects its head. Two massive claws provide the creature with formidable weapons."
    ],
    arrival: [],
    flee: [
      "A sand beetle meanders {direction}."
    ],
    death: [
      "The sand beetle falls to the ground and lies twitching for a moment before going still.",
      "The sand beetle kicks a leg one last time and lies still."
    ],
    decay: [
      "A sand beetle's legs shrivel up beneath it as it decays into dust."
    ],
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
