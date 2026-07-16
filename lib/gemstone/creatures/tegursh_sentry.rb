{
  schema_version: 3,
  name: "tegursh sentry",
  noun: "",
  url: "https://gswiki.play.net/tegursh_sentry",
  picture: "",
  level: 30,
  family: "Tegursh",
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
  max_hp: 350,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Sorcerer's Isle",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: (215..225)
      },
      {
        name: "Jeddart-axe",
        as: 225
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Shield Charge"
      }
    ],
    special_abilities: [
      {
        name: "Tail sweep"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: 199,
    ranged: 189,
    bolt: 197,
    udf: nil,
    bar_td: 96,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 115,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 120,
    mjs_td: 111,
    mns_td: 111,
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
    skin: "a tegursh claw",
    other: nil
  },
  messaging: {
    description: [
      "Taller than a common human and of substantially heavier build, the tegursh sentry is a solid mass of bone and gristle overlaid with bony plates that cover most of his torso, legs, and arms. Beady, black eyes rimmed in red peer out from a twisted, deformed face, clearly orcish but with an elongated snout. The sentry's arms are as thick as tree branches, ending in three incredibly sharp claws. Unlike any orc you have seen, this creature has an armored tail tipped with pointy spikes."
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
