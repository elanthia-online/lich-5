{
  schema_version: 3,
  name: "spectral miner",
  noun: "",
  url: "https://gswiki.play.net/spectral_miner",
  picture: "",
  level: 40,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Shadow Valley",
      rooms: []
    }
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
    asg: "7",
    immunities: [],
    melee: 183,
    ranged: nil,
    bolt: (152..187),
    udf: nil,
    bar_td: 158,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (143..166),
    wiz_td: 164,
    mje_td: 159,
    mne_td: 163,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Spirit Defense (103)",
      "Spirit Shield (202)"
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
    skin: nil,
    other: "No"
  },
  messaging: {
    description: [
      "This somewhat orc-like looking humanoid creature is surrounded with an eerie white glow and appears to be transparent. An abundance of excessively wrinkled skin and long bushy grey eyebrows serve to make spectral miner appear ancient."
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
