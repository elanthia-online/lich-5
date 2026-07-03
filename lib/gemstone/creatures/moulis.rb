{
  schema_version: 3,
  name: "moulis",
  noun: "",
  url: "https://gswiki.play.net/moulis",
  picture: "",
  level: 75,
  family: "Plant",
  type: "Plantlife",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Magical",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Blighted Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Attack",
        as: 380
      }
    ],
    bolt_spells: [
      {
        name: "Cone of Elements (518)"
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: (331..349)
      },
      {
        name: "Immolation (519)"
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Splinter Barrage"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 211,
    udf: nil,
    bar_td: (264..270),
    cle_td: (282..291),
    emp_td: (283..292),
    pal_td: nil,
    ran_td: nil,
    sor_td: (299..317),
    wiz_td: nil,
    mje_td: 316,
    mne_td: 332,
    mjs_td: nil,
    mns_td: (277..286),
    mnm_td: nil,
    defensive_spells: [
      "Elemental Bias (508)",
      "Elemental Deflection (507)",
      "Stone Skin (520)",
      "Strength (509)"
    ],
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
      "<pre{{log2|margin-right=26em}}>Waving its myriad of oddly flexible, root-like appendages, the moulis scuttles about its home area.  It is not known what the moulis searches for, as observations have usually yielded a quick death for the observer, yet it is known that the moulis is an intelligent, lethal foe capable of commanding the forces of magic as well as a powerful physical attack.  It appears to be nothing more than a writhing mass of tubers, roots and thin hair strands in various shades of brown--until a vicious attack springs from the center of the creature.</pre>"
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
