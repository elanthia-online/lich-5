{
  schema_version: 3,
  name: "black bear",
  noun: "",
  url: "https://gswiki.play.net/black_bear",
  picture: "",
  level: 16,
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
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Neartofar Forest",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 180
      },
      {
        name: "Claw (attack)",
        as: 190
      },
      {
        name: "Charge (attack)",
        as: 190
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (104..109),
    ranged: nil,
    bolt: 97,
    udf: nil,
    bar_td: (48..54),
    cle_td: (45..48),
    emp_td: 48,
    pal_td: nil,
    ran_td: 48,
    sor_td: 48,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 48,
    mns_td: (45..48),
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
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a bear hide",
    other: nil
  },
  messaging: {
    description: [
      "The black bear is a medium sized bear with a body about six feet long and appears to weigh around 440 pounds. Mostly blackish in color, asone would expect from a black bear, its muzzle is somewhat lighter and a distinct V-shaped patch of cream colored fur can be found on the chest. Also of note are the ears which appear much larger than those of other bears."
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
