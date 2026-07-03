{
  schema_version: 3,
  name: "sacristan spirit",
  noun: "",
  url: "https://gswiki.play.net/sacristan_spirit",
  picture: "",
  level: 25,
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
  bcs: true,
  max_hp: 205,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Lunule Weald",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "a twisted black steel half moon",
        as: 211
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blinding (311)",
        cs: 142
      },
      {
        name: "Frenzy (216)",
        cs: 142
      },
      {
        name: "Mind Jolt (706)",
        cs: 146
      },
      {
        name: "Silence (210)",
        cs: 142
      }
    ],
    offensive_spells: [
      {
        name: "Bravery (211)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: 205,
    ranged: nil,
    bolt: 137,
    udf: nil,
    bar_td: (81..92),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 96,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 103,
    mjs_td: nil,
    mns_td: 92,
    mnm_td: nil,
    defensive_spells: [
      "Prayer of Protection",
      "Prismatic Guard",
      "Spirit Shield",
      "Spirit Warding I",
      "Thurfel's Ward"
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
    other: "[[Glimmering blue essence shard]]<br>[[Glimmering blue mote of essence]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Draped in tattered robes, the spirit forever wanders the forests and swamps in search of the sacred objects he once guarded in life.  Forever frustrated in his attempts to find his cherished but long-destroyed artifacts, the spirit lashes out violently at all those who would dare trespass into his unholy domain.</pre>"
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
