{
  schema_version: 3,
  name: "waern",
  noun: "",
  url: "https://gswiki.play.net/waern",
  picture: "",
  level: 49,
  family: "Canine",
  type: "Quadruped",
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
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Bonespear Tower",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (276..290)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Grapple"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (248..266),
    bolt: nil,
    udf: 276,
    bar_td: 165,
    cle_td: 180,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (190..199),
    wiz_td: 200,
    mje_td: 200,
    mne_td: 199,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: true,
    skin: "a waern fur",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The waern is a vicious-looking embodiment of canine malice and tenacity.  The waern's fiendish green eyes glow with insane appetite and her mangy pelt is so ragged, the rotting bones show through in spots.  Long, malicious teeth curve out of the waern's rotting muzzle, and the tail that curves over the waern's back is hardly more than segments of bone interspersed with a few pieces of fuzzy, matted hair.  Floating over the ground, her paws scarcely leaving a track, the waern dodges almost quicker than the eye can follow.</pre>"
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
