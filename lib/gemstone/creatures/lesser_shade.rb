{
  schema_version: 3,
  name: "lesser shade",
  noun: "",
  url: "https://gswiki.play.net/lesser_shade",
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
  max_hp: 44,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehnimer's Landing",
      rooms: []
    },
    {
      name: "Coastal Cliffs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 43
      },
      {
        name: "Falchion",
        as: 43
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 10
      },
      {
        name: "Repel (fear)",
        cs: 14
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "18",
    immunities: [],
    melee: "-17",
    ranged: nil,
    bolt: "-20",
    udf: nil,
    bar_td: 6,
    cle_td: 6,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
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
    other: "Alchemy (common)"
  },
  messaging: {
    description: [
      "The lesser shade bears the outline of a man and looks solid, but you can see faint images of the background through it."
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
