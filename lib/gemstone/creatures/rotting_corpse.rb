{
  schema_version: 3,
  name: "rotting corpse",
  noun: "",
  url: "https://gswiki.play.net/rotting_corpse",
  picture: "",
  level: 32,
  family: "Zombie",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Varunar",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scythe",
        as: 266
      },
      {
        name: "Bite (attack)",
        as: 233
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
    asg: "9N",
    immunities: [],
    melee: 230,
    ranged: nil,
    bolt: 194,
    udf: 256,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (105..123),
    wiz_td: 120,
    mje_td: 120,
    mne_td: 119,
    mjs_td: nil,
    mns_td: 109,
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
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "[[Glimmering blue essence dust]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Stumbling, staggering, cartwheeling wildly, the rotting corpse moves like a large marionette controlled by a drunken hand.  Bits of flesh, sinew and disintegrating rags hang from its bony humanoid skeleton.  The corpse hunts the living relentlessly, driven by an envy of the living world apparent in her hate-filled eyes.</pre>"
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
