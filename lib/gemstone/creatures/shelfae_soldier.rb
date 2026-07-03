{
  schema_version: 3,
  name: "shelfae soldier",
  noun: "",
  url: "https://gswiki.play.net/shelfae_soldier",
  picture: "",
  level: 7,
  family: "Shelfae",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Coastal Cliffs",
      rooms: []
    },
    {
      name: "Marshtown",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trident",
        as: 102
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
    asg: "11",
    immunities: [],
    melee: (32..50),
    ranged: nil,
    bolt: 13,
    udf: nil,
    bar_td: 21,
    cle_td: nil,
    emp_td: 21,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
    mjs_td: 21,
    mns_td: 21,
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
    skin: "a shelfae scale",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The shelfae soldier is the vanguard of the shelfae reptilian forces.  Bipedal, it stands approximately five feet tall with orange-tinged scales and clawed hands and feet.  The shelfae soldier does not range very far from its commanding officer, and usually can be found guarding strategic points in the defensive system.  It views the world through cold reptilian eyes and shows little mercy when confronting an enemy to its lands.</pre>"
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
