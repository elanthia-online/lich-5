{
  schema_version: 3,
  name: "ghost",
  noun: "",
  url: "https://gswiki.play.net/ghost",
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
  max_hp: 51,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Short sword",
        as: 58
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
    asg: "1N",
    immunities: [],
    melee: "-2",
    ranged: nil,
    bolt: "-13",
    udf: 48,
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
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Found near graveyards and other resting places of the dead, the ghost presents itself as a pale reflection of what it once was, a living, breathing person.  Eyes long rotted away, appendages barely discernable, it knows not why it fights, but attacks the living at every occasion.  The ghost fights relentlessly, knowing no fear, until victorious or utterly destroyed.  Its agonized, horrific moans often chill those who face it.</pre>"
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
