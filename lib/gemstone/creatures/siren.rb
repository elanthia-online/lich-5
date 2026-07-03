{
  schema_version: 3,
  name: "siren",
  noun: "",
  url: "https://gswiki.play.net/siren",
  picture: "",
  level: 96,
  family: "Fey",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Ruined Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 423
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 402
      },
      {
        name: "Holding Song (1001)",
        cs: 402
      },
      {
        name: "Lullabye (1005)",
        cs: 402
      },
      {
        name: "Song of Depression (1015)",
        cs: 402
      },
      {
        name: "Song of Unravelling (1013)",
        cs: 402
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: 429,
    ranged: nil,
    bolt: (336..453),
    udf: nil,
    bar_td: 363,
    cle_td: 389,
    emp_td: nil,
    pal_td: 329,
    ran_td: nil,
    sor_td: 406,
    wiz_td: nil,
    mje_td: (425..435),
    mne_td: (411..423),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I",
      "Elemental Defense II",
      "Elemental Defense III",
      "Song of Mirrors",
      "Song of Tonis"
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
    other: "pristine siren's hair"
  },
  messaging: {
    description: [
      "The siren is a peculiar vision of beauty from the sea.  Though her lower body is that of an iridescently scaled fish, it takes away nothing from the rest of her ravishingly feminine figure draped in long, golden blonde hair and surrounded by a mystical aura.  Discretely hidden webbing beneath her arms that aids in navigating deep waters has given rise to the erroneous legend that the siren can also fly.  The soothing song from these strangely beautiful creatures has pulled many sailors to their deaths, and every moment that the siren gazes at you with her captivating brilliant blue eyes and serenades you with liquid notes from her glistening full lips is a moment that you plunge deeper into danger yourself."
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
