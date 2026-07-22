{
  schema_version: 3,
  name: "arachne acolyte",
  noun: "",
  url: "https://gswiki.play.net/arachne_acolyte",
  picture: "",
  level: 23,
  family: "Humanoid",
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
  max_hp: 190,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Spider Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "War hammer",
        as: (200..275)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Frenzy (216)",
        cs: 118
      },
      {
        name: "Web (118)",
        cs: 118
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Disarm"
      },
      {
        name: "Tackle"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (180..220),
    ranged: nil,
    bolt: 114,
    udf: nil,
    bar_td: 67,
    cle_td: 66,
    emp_td: 54,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: (67..72),
    mje_td: (67..72),
    mne_td: 73,
    mjs_td: 76,
    mns_td: 66,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Spirit Fog (106)"
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
      "The Arachne acolyte's head is clean shaven and bald. Where hair once grew, ornate tattoos of deep red hue decorate every visible bare body part. The Arachne acolytes are muscular but lean. Long years of study and training has produced fanatical allegiance to Arachne. Any semblance of humanity has long since been exorcised through torture and meditation. Only the zealous duty of Arachne now compels their existence."
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
