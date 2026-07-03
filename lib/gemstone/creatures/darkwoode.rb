{
  schema_version: 3,
  name: "darkwoode",
  noun: "",
  url: "https://gswiki.play.net/darkwoode",
  picture: "",
  level: 13,
  family: "Tree",
  type: "Plantlife",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 120,
  speed: "5",
  height: nil,
  size: "",
  areas: [
    {
      name: "The Toadwort",
      rooms: []
    },
    {
      name: "Sentoph",
      rooms: []
    },
    {
      name: "Foggy Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 127
      },
      {
        name: "Ensnare",
        as: 137
      }
    ],
    bolt_spells: [
      {
        name: "Minor Water (903)",
        as: 125
      },
      {
        name: "Major Shock (910)",
        as: 125
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      },
      {
        name: "Tremors (909)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: 73,
    ranged: nil,
    bolt: 57,
    udf: nil,
    bar_td: 39,
    cle_td: 39,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 39,
    wiz_td: nil,
    mje_td: 39,
    mne_td: 39,
    mjs_td: 39,
    mns_td: 39,
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
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A skeletal tree-trunk with long straggling branches, the darkwoode holds the unliving force of a once sentient tree-spirit.  An unfelt breeze seems to stir the dead and decaying leaves that still cling to it, giving it a travesty of the beauty it once held as a living tree.  Given its original form long ago to protect sacred groves, it remains now, warped and twisted, yet still attempting to carry out the duties it failed in long ago.</pre>"
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
