{
  schema_version: 3,
  name: "lesser mummy",
  noun: "",
  url: "https://gswiki.play.net/lesser_mummy",
  picture: "",
  level: 6,
  family: "Humanoid",
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
  max_hp: 91,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 108
      },
      {
        name: "Ensnare",
        as: 118
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
    asg: "8N",
    immunities: [],
    melee: (34..40),
    ranged: nil,
    bolt: 33,
    udf: 60,
    bar_td: 18,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 18,
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
    skin: "a mummy shroud",
    other: nil
  },
  messaging: {
    description: [
      "The lesser mummy scrapes slowly across the floor, dragging its form tirelessly in an attempt to find final rest. Its decayed flesh is barely contained in the remnants of its embalming strips, torn and unwrapping in its wake. Once a member of a proud and wealthy family, it has left its sarcophagus to discover someone who can help it and to kill all those who cannot."
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
