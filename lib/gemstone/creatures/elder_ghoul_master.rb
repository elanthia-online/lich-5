{
  schema_version: 3,
  name: "elder ghoul master",
  noun: "",
  url: "https://gswiki.play.net/elder_ghoul_master",
  picture: "",
  level: 18,
  family: "Ghoul",
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
  max_hp: 160,
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
        name: "Claidhmore",
        as: 128
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
    asg: "12",
    immunities: [],
    melee: (58..148),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
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
    skin: "a ghoul master claw",
    other: nil
  },
  messaging: {
    description: [
      "The elder ghoul master is a mass of blackened muscle in humanoid form. Striding boldly upright and with a determined gaze, the elder ghoul master marches through the world of the dead, seeking the bodies of the recently deceased. Though, in fact, dead itself, its putrid breath reveals its consumption of a steady diet of decayed flesh. If none can be found, the elder ghoul master is more than happy to cause the living to become the recently deceased."
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
