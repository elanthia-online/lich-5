{
  schema_version: 3,
  name: "arachne priest",
  noun: "",
  url: "https://gswiki.play.net/arachne_priest",
  picture: "",
  level: 26,
  family: "Humanoid",
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
      name: "Spider Temple",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: 219
      },
      {
        name: "Scimitar",
        as: 219
      },
      {
        name: "Short sword",
        as: 219
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Web (118)",
        cs: 118
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike (117)"
      },
      {
        name: "Heroism (215)"
      },
      {
        name: "Benediction (307)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: 189,
    ranged: (160..180),
    bolt: nil,
    udf: nil,
    bar_td: 92,
    cle_td: 102,
    emp_td: 95,
    pal_td: nil,
    ran_td: nil,
    sor_td: (108..115),
    wiz_td: 107,
    mje_td: 107,
    mne_td: 107,
    mjs_td: 104,
    mns_td: 104,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding II (107)",
      "Spell Shield (219)",
      "Prayer of Protection (303)",
      "Warding Sphere (310)",
      "Prayer (313)"
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
    skin: nil,
    other: "[[Glimmering blue essence shard]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The Arachne priest's lithe body is covered by heavy silk robes that also cowl most of the facial features.  A single visible image of a black spider over a crimson background is clearly emblazoned upon the backside.  Draped in their macabre attire, the Arachne priest goes about its zealous duties in worship of Arachne.  Upon close inspection, one can make out partial shapes of sigils formed by welts and mutilations on the hands and face.</pre>"
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
