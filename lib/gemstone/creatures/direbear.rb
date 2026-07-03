{
  schema_version: 3,
  name: "direbear",
  noun: "",
  url: "https://gswiki.play.net/direbear",
  picture: "",
  level: 64,
  family: "Bear",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Red Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 349
      },
      {
        name: "Claw (attack)",
        as: (340..355)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Bertrandt's Bellow"
      },
      {
        name: "Gerrelle's Growl"
      },
      {
        name: "Red eyes (AS boost)"
      }
    ],
    maneuvers: [
      {
        name: "Bearhug"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: 244,
    ranged: nil,
    bolt: 184,
    udf: 318,
    bar_td: (234..240),
    cle_td: 259,
    emp_td: (243..258),
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 255,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "direbear fang",
    other: "No"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>\nThe direbear is a huge powerful beast with baleful red eyes that seem to bore through to the very soul. Impressively large bone deposits protrude across the breadth of the beast's back and neck. Large teeth that seem too big even for the massive maw can easily be seen even when the powerful jaws are closed. Mist, or perhaps tendrils of smoke, occasionally drift up from the flaring nostrils. Sharp eyes, a sense of smell to match, and a cunning said to rival demons make a direbear something to be avoid.\n</pre>\n{{TOC limit}}"
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
