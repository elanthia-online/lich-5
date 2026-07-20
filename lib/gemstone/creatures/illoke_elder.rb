{
  schema_version: 3,
  name: "illoke elder",
  noun: "",
  url: "https://gswiki.play.net/illoke_elder",
  picture: "",
  level: 86,
  family: "Giant",
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
  max_hp: 600,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Thanatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stomp (attack)",
        as: "+339"
      },
      {
        name: "Sledgehammer",
        as: "+408"
      },
      {
        name: "Stalagmite",
        as: "+425"
      },
      {
        name: "Rock (hurled)",
        as: "+423"
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Stone Fist (514)"
      }
    ],
    offensive_spells: [
      {
        name: "Major Elemental Wave (435)"
      },
      {
        name: "Elemental Disjunction (530)"
      },
      {
        name: "Sandstorm (914)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: "+305",
    ranged: "+285-309",
    bolt: "+202",
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
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
    skin: nil,
    other: "radiant crimson essence shard"
  },
  messaging: {
    description: [
      "The enormous form of the Illoke elder occupies a large section of the area, over twenty feet at his full height. He carries himself with an air of confident superiority, casting a hate-filled gaze around him. Thick and rough grey skin covers him from head to toe, providing protection against all but the strongest of blows. A deep crimson symbol of Illoke is chiseled into his forehead, bathing his face in a lurid illumination."
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
