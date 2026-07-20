{
  schema_version: 3,
  name: "monastic lich",
  noun: "",
  url: "https://gswiki.play.net/monastic_lich",
  picture: "",
  level: 27,
  family: "Humanoid",
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
  max_hp: 220,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Monastery",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "claidhmore",
        as: (180..255)
      },
      {
        name: "kris",
        as: (180..255)
      },
      {
        name: "whip",
        as: (180..255)
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: (178..193)
      }
    ],
    warding_spells: [
      {
        name: "Blind (311)",
        cs: 150
      },
      {
        name: "Cold Snap (512)",
        cs: (159..162)
      },
      {
        name: "Silence (210)",
        cs: 150
      }
    ],
    offensive_spells: [
      {
        name: "Bravery (211)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Forget"
      },
      {
        name: "AS Boost"
      },
      {
        name: "Spirit Drain"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (254..272),
    ranged: nil,
    bolt: 220,
    udf: nil,
    bar_td: nil,
    cle_td: (89..117),
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (106..126),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 120,
    mjs_td: nil,
    mns_td: 115,
    mnm_td: nil,
    defensive_spells: [
      "Prayer of Protection (303)",
      "Prismatic Guard (905)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Thurfel's Ward (503)"
    ],
    defensive_abilities: [],
    special_defenses: [
      "Shake off stuns"
    ]
  },
  special_other: "Summon Ki-lin",
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
      "Garbed in the tattered finery of his lost faith, this monastic lich is a decomposing humanoid of indiscernable heritage. Standing as high as a human, his distinguishing features have skin wrapped about a thin skeletal frame. Held together by nothing more than smouldering malice and some long forgotten curse, the monastic lich's flesh falls off in stinking bits as he shudders in agonizing ecstasy. In the center of his chest is a ragged hole, as if his heart had been ripped from its body."
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
