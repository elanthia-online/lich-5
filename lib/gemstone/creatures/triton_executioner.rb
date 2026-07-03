{
  schema_version: 3,
  name: "triton executioner",
  noun: "",
  url: "https://gswiki.play.net/triton_executioner",
  picture: "",
  level: 96,
  family: "Triton",
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
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Ruined Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: 433
      },
      {
        name: "Heavy crossbow",
        as: (433..448)
      },
      {
        name: "longsword",
        as: 433
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Coup de Grace"
      },
      {
        name: "Cutthroat"
      },
      {
        name: "Drown"
      },
      {
        name: "Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 331,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 340,
    cle_td: 358,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 381,
    wiz_td: nil,
    mje_td: 393,
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "The triton executioner scans his surroundings with merciless eyes as if seeking his next client. Heavy, leathery lips are pulled into a perpetually disgusted sneer, pinching the creature's nostrils into narrow slits. Animal muscles, powerfully knotted beneath his moist blue-green skin, seem ready to spring in any direction. The executioner wears a dark blue tabard emblazoned with a silver wave upon the chest."
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
