{
  schema_version: 3,
  name: "wasp nest",
  noun: "nest",
  url: "https://gswiki.play.net/wasp_nest",
  picture: "",
  level: 43,
  family: "Wasp",
  type: "Insect",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 143,
  speed: nil,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Fhorian Village",
      uids: [3030011..3030023, 3030225..3030234, 3030250..3030254]
    },
    {
      name: "Volcano",
      uids: [3050008..3050036, 3052001..3052025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dreadful droning of their wings",
        as: 367
      }
    ],
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
    ranged: (191..420),
    bolt: (191..420),
    udf: (231..242),
    bar_td: 72,
    cle_td: 86,
    emp_td: 85,
    pal_td: (59..62),
    ran_td: 62,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 103,
    mne_td: 103,
    mjs_td: 217,
    mns_td: 217,
    mnm_td: 60,
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: "reticulated orbs",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Smooth black basalt forms a squat cone, taller than many giantmen. The rock looks almost to have been molded or poured into shape, lacking any sign of having been worked. The top is apparently open, allowing the wasps access to the interior. A deep hum radiates from the nest, implying a feverish level of activity inside."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [
      "The wasp nest collapses into a pile of rubble.",
      "A wasp nest decays into dust."
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
