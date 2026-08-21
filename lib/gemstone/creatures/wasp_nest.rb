{
  schema_version: 3,
  name: "wasp nest",
  noun: "",
  url: "https://gswiki.play.net/wasp_nest",
  picture: "",
  level: 43,
  family: "Wasp",
  type: "Insect",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [],
  bcs: true,
  max_hp: 143,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Fhorian Village",
      rooms: []
    },
    {
      name: "Lava Flows",
      rooms: []
    }
  ],
  spawns: [
    { zone: 3030, count: 3, uid_ranges: [[3030011, 3030023], [3030225, 3030234], [3030250, 3030254]] },
    { zone: 3050, count: 2, uid_ranges: [[3050008, 3050036]] },
    { zone: 3052, count: 1, uid_ranges: [[3052001, 3052025]] }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (139..206),
    ranged: nil,
    bolt: nil,
    udf: 242,
    bar_td: 72,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "reticulated orbs"
  },
  messaging: {
    description: [
      "Smooth black basalt forms a squat cone, taller than many giantmen. The rock looks almost to have been molded or poured into shape, lacking any sign of having been worked. The top is apparently open, allowing the wasps access to the interior. A deep hum radiates from the nest, implying a feverish level of activity inside."
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
