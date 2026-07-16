{
  schema_version: 3,
  name: "sheruvian harbinger",
  noun: "",
  url: "https://gswiki.play.net/sheruvian_harbinger",
  picture: "",
  level: 63,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      rooms: []
    },
    {
      name: "The Broken Lands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (324..414)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 284
      },
      {
        name: "Frenzy (216)",
        cs: 284
      },
      {
        name: "Mind Jolt (706)",
        cs: 291
      },
      {
        name: "Silence (210)",
        cs: 284
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
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (216..231),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 210,
    cle_td: nil,
    emp_td: 219,
    pal_td: 196,
    ran_td: nil,
    sor_td: 244,
    wiz_td: nil,
    mje_td: 248,
    mne_td: nil,
    mjs_td: nil,
    mns_td: 229,
    mnm_td: nil,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)"
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
    skin: "No",
    other: "Glowing violet essence dust"
  },
  messaging: {
    description: [
      "The Sheruvian harbinger is a handsome woman with hypnotic eyes and fair skin. Her demeanor appears emotionless, but you can see some sort of evil fire burning within those dark pupils. A sleek, black breastplate covers most of her torso, and you can see it is made of fine quality. The mere look of the harbinger reminds most people of the tales of the Harbinger of Chaos, spawned forth to do great evil."
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
