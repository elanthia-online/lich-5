{
  schema_version: 3,
  name: "tomb wight",
  noun: "",
  url: "https://gswiki.play.net/tomb_wight",
  picture: "",
  level: 15,
  family: "Wight",
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
  max_hp: 135,
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
        name: "Broadsword"
      },
      {
        name: "Two-handed sword",
        as: 157
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
    asg: "18",
    immunities: [],
    melee: (71..137),
    ranged: nil,
    bolt: nil,
    udf: (125..166),
    bar_td: 45,
    cle_td: 45,
    emp_td: 45,
    pal_td: 45,
    ran_td: 45,
    sor_td: 45,
    wiz_td: 45,
    mje_td: 45,
    mne_td: 45,
    mjs_td: 45,
    mns_td: 45,
    mnm_td: 45,
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
    skin: "a wight claw",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>A tomb wight is a mass of blackened muscle in humanoid form.  Striding boldly upright and with a determined gaze, a tomb wight marches through the world of the dead, seeking the bodies of the recently deceased.  Though, in fact, dead itself, its putrid breath reveals its consumption of a steady diet of decayed flesh.  If none can be found, a tomb wight is more than happy to cause the living to become the recently deceased.</pre>"
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
