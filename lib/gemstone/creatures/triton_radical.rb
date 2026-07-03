{
  schema_version: 3,
  name: "triton radical",
  noun: "",
  url: "https://gswiki.play.net/triton_radical",
  picture: "",
  level: 100,
  family: "Triton",
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
        name: "Scaling fork",
        as: 430
      },
      {
        name: "Trident"
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Censure (316)",
        cs: 415
      },
      {
        name: "Divine Strike (1615)",
        cs: 424
      },
      {
        name: "Divine Wrath (335)",
        cs: 403
      },
      {
        name: "Frenzy (216)",
        cs: 409
      },
      {
        name: "Judgment (1630)",
        cs: 409
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Bull Rush"
      },
      {
        name: "Charge"
      },
      {
        name: "Shield Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (338..407),
    ranged: nil,
    bolt: (275..326),
    udf: nil,
    bar_td: 375,
    cle_td: nil,
    emp_td: nil,
    pal_td: 345,
    ran_td: nil,
    sor_td: 420,
    wiz_td: nil,
    mje_td: (428..453),
    mne_td: (414..438),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Divine Shield",
      "Fasthr's Reward",
      "Lesser Shroud",
      "Mantle of Faith",
      "Warding Sphere"
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
    skin: "an elongated triton spine",
    other: nil
  },
  messaging: {
    description: [
      "Glaring angrily and gnashing his sharp yellowed teeth, the triton radical stalks along muttering to himself as if involved in angry debate with a phantasmal antagonist. Pale, red-rimmed eyes sit deep in a heavy-boned skull, which perches upon a long, slender neck. The radical's body pitches forward alarmingly, so only the weight of his tail prevents a return to a four-legged posture. Upon his tapered brow is set a golden crown bearing a large, wave-etched crystal drop."
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
