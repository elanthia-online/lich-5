{
  schema_version: 3,
  name: "bog wight",
  noun: "",
  url: "https://gswiki.play.net/bog_wight",
  picture: "",
  level: 44,
  family: "Wight",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Fethayl Bog",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 274
      },
      {
        name: "Claw",
        as: 284
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
    asg: "9",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: (199..204),
    udf: nil,
    bar_td: (126..132),
    cle_td: 145,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 153,
    wiz_td: nil,
    mje_td: 163,
    mne_td: 153,
    mjs_td: nil,
    mns_td: 144,
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
    other: "Glowing violet mote of essence"
  },
  messaging: {
    description: [
      "Cloaked in a thick shroud of mist that perpetually follows it, the bog wight moves with a quick grace. Two burning red orbs stare out from its gaunt, emaciated face, devoid of any compassion or mercy. A fanged, lipless mouth accompanies its haunting eyes, the maggot-white skin of its face pulled so taught over its skull that it gives the impression of a bestial grin. Wisps of the miasma that enshrouds its nearly skeletal form whipback and forth as it glides about, writhing against its tattered robes."
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
