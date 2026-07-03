{
  schema_version: 3,
  name: "dark apparition",
  noun: "",
  url: "https://gswiki.play.net/dark_apparition",
  picture: "",
  level: 5,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 65,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 48
      },
      {
        name: "Claw",
        as: 58
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 46
      },
      {
        name: "Mana Disruption (702)",
        cs: 46
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: 51,
    ranged: nil,
    bolt: "-20",
    udf: nil,
    bar_td: 15,
    cle_td: 15,
    emp_td: 15,
    pal_td: 15,
    ran_td: 15,
    sor_td: 15,
    wiz_td: 15,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 15,
    mns_td: 15,
    mnm_td: 15,
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
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>It is difficult to focus on the shape of the dark apparition.  It wavers and shifts as an image seen through dark waters yet each shape it assumes has some aspect of horror and bloody death.  One form is that of a corpse mutilated beyond words with arms hacked to stumps yet tipped with shining claws.  Another is that of a waif horribly burned and scarred so that her features run like melted wax.  Yet another is something apparently torn apart by huge razors...flesh hanging in sheets that blow in some ill-spawned breeze like leaves of sea-grass in the current.  The sight would make any normal person turn and gag, being unable to bear any more.</pre>"
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
