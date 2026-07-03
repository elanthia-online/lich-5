{
  schema_version: 3,
  name: "dark orc",
  noun: "",
  url: "https://gswiki.play.net/dark_orc",
  picture: "",
  level: 12,
  family: "Orc",
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
  max_hp: 150,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    },
    {
      name: "Yander's Farm",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: 157
      },
      {
        name: "Scimitar",
        as: 157
      },
      {
        name: "Morning star",
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
    asg: "14",
    immunities: [],
    melee: (65..75),
    ranged: (39..57),
    bolt: nil,
    udf: nil,
    bar_td: 36,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: 36,
    sor_td: 36,
    wiz_td: nil,
    mje_td: 36,
    mne_td: 36,
    mjs_td: 36,
    mns_td: 36,
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
    skin: "an orc ear",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The dark orc obtains her name not from having dark coloration, but from her proclivity for seeking out dark places in which to live.  In fact, the dark orc's body is covered by a fine layer of salt-and-pepper fur, with a preponderance of the lighter shade.  Thick of skull and lacking good reasoning ability, the dark orc subsists on whatever creatures are foolish enough to find their way into her line of sight with no real concern as to how tough to kill or dangerous they might be.</pre>"
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
