{
  schema_version: 3,
  name: "zombie",
  noun: "",
  url: "https://gswiki.play.net/zombie",
  picture: "",
  level: 23,
  family: "Zombie",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Icemule Environs",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (200..208)
      },
      {
        name: "Claw",
        as: (198..210)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: 125,
    ranged: 118,
    bolt: 118,
    udf: 169,
    bar_td: (63..69),
    cle_td: (67..76),
    emp_td: 72,
    pal_td: nil,
    ran_td: nil,
    sor_td: (68..80),
    wiz_td: nil,
    mje_td: 76,
    mne_td: 77,
    mjs_td: 72,
    mns_td: (69..78),
    mnm_td: (63..78),
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
    skin: "zombie scalp",
    other: nil
  },
  messaging: {
    description: [
      "Pity the poor zombie, an animated corpse abandoned long ago by her creator. The skin of the zombie has turned a sickly grey, her clothing hangs in tattered ribbons, and she barely keeps control over her death-stiffened muscles. Her mouth, once sewn shut to hold the salt necessary in the animation process, has broken open again, salt dribbling from the parched, thread-covered lips. The zombie verbally threatens and attacks anyone she believes may interfere with her quest to return to the grave."
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
