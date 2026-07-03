{
  schema_version: 3,
  name: "ithzir scout",
  noun: "",
  url: "https://gswiki.play.net/ithzir_scout",
  picture: "",
  level: 89,
  family: "Ithzir",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Ta'Faendryl",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (414..424)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Cheapshots"
      },
      {
        name: "Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: nil,
    ranged: (323..343),
    bolt: (346..392),
    udf: nil,
    bar_td: nil,
    cle_td: (335..339),
    emp_td: (328..334),
    pal_td: nil,
    ran_td: nil,
    sor_td: (339..354),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 368,
    mjs_td: nil,
    mns_td: 328,
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
    other: "crystal-edged weapons"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Wide, pupil-less green eyes peer about, quickly assessing both threats and terrain.  The Ithzir scout stalks in a fluid, half-crouch that is as graceful as it is lightning fast, his whole demeanor underscoring his menace and obvious intelligence.  The Ithzir scout is slightly taller than a human, and while his humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance.  The scout wears a charcoal grey tunic with no apparent identifiers of his station.</pre>"
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
