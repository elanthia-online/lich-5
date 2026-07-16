{
  schema_version: 3,
  name: "triton fanatic",
  noun: "",
  url: "https://gswiki.play.net/triton_fanatic",
  picture: "",
  level: 100,
  family: "Triton",
  type: "Biped",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Atoll",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Hammer of Kai",
        as: "423 to 464"
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Pious Trial (1602)",
        cs: "430 to 442"
      },
      {
        name: "Repentance (1615)",
        cs: "430 to 442"
      }
    ],
    offensive_spells: [
      {
        name: "Arm of the Arkati (1605)"
      },
      {
        name: "Zealot (1617)"
      },
      {
        name: "Fervor (1618)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      }
    ],
    special_abilities: [
      {
        name: "Cyclone"
      },
      {
        name: "Mstrike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "17N",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "422 to 455",
    wiz_td: nil,
    mje_td: nil,
    mne_td: "433 to 468",
    mjs_td: nil,
    mns_td: 415,
    mnm_td: nil,
    defensive_spells: [
      "Mantle of Faith (1601)",
      "Higher Vision (1610)",
      "Patron's Blessing (1611)",
      "Faith Shield (1619)"
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
    skin: "thick triton spine",
    other: nil
  },
  messaging: {
    description: [
      "A triton fanatic visibly twitches as he clutches a contorted driftwood fetish within his sigil-gouged fingers, his crazed bloodshot eyes darting to and fro beneath a shredded miter of dark oilskin. The last vestiges of a hair-sewn tunic barely cling to his emaciated form, stained in rust-colored splotches from collar to knee, and lashed together with knots of thick sinew. Branded across his forehead is the image of a broken trident, the forks splayed between his brows."
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
