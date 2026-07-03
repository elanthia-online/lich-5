{
  schema_version: 3,
  name: "phantom",
  noun: "",
  url: "https://gswiki.play.net/phantom",
  picture: "",
  level: 2,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 42,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 28
      },
      {
        name: "Dagger",
        as: 0
      }
    ],
    bolt_spells: [
      {
        name: "Minor Shock (901)",
        as: 35
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: "-23",
    ranged: nil,
    bolt: "-24",
    udf: 26,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: 6,
    ran_td: 6,
    sor_td: 6,
    wiz_td: 6,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
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
      "Barely still connected to the living plane, the phantom flickers in and out as it confronts those that would intrude upon its rest. The outlines of its shape are barely apparent, suggesting a once-humanoid appearance, now disguised in a transparent, flickering whiteness. The phantom must move and strike quickly, as it is only able to glimpse the figures of the targets around it when the phantom is at its most visible state."
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
