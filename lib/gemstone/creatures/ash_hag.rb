{
  schema_version: 3,
  name: "ash hag",
  noun: "",
  url: "https://gswiki.play.net/ash_hag",
  picture: "",
  level: 31,
  family: "Witch",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Element-based",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Greymist Wood",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Slap",
        as: 210
      },
      {
        name: "Bite (attack)",
        as: 180
      }
    ],
    bolt_spells: [
      {
        name: "Minor Fire (906)",
        as: 200
      }
    ],
    warding_spells: [
      {
        name: "Immolation (519)",
        cs: 183
      }
    ],
    offensive_spells: [
      {
        name: "Elemental Wave (410)"
      },
      {
        name: "Fire Storm"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: nil,
    ranged: 142,
    bolt: 149,
    udf: nil,
    bar_td: 110,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 127,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 141,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Thurfel's Ward (503)"
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a hag nose",
    other: "glimmering blue essence shard"
  },
  messaging: {
    description: [
      "You are not quite sure what to make of the ash hag, as you have never seen anything that looks quite like it. Stopping a moment, you try to commit this creature to memory so that you can tell tales of it to your fellow adventurers back in the safety of the local tavern."
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
