{
  schema_version: 3,
  name: "pale scaled shaper",
  noun: "",
  url: "https://gswiki.play.net/pale_scaled_shaper",
  picture: "",
  level: 102,
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
  max_hp: 265,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Sanctum",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [
      {
        name: "Major Fire",
        as: "+454"
      }
    ],
    warding_spells: [
      {
        name: "Disintegrate",
        cs: "+353"
      },
      {
        name: "Cloak of Shadows",
        cs: "+431"
      }
    ],
    offensive_spells: [
      {
        name: "Gas cloud"
      },
      {
        name: "Major Elemental Wave"
      },
      {
        name: "Spiritual Abolition"
      },
      {
        name: "Condemn"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: "555+",
    ranged: (429..616),
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 349,
    ran_td: 368,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I",
      "Spirit Warding II",
      "Lesser Shroud",
      "Cloak of Shadows",
      "Spirit Shield",
      "Bravery",
      "Thurfel's Ward"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Summons sidewinder cobras",
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
      "A pale scaled shaper is far taller than a woman ought to be, with a stretched appearance like that of a doll tugged by battling children. That is, if she is even female: the pale robes that she wears, with their faint appliqued patterns of winking copper scales, betray only the most suggestive promise of a feminine form beneath. There is something upsettingly inhuman about the shaper's face, which has the shape and proportions of a human's, but eyes that glow like green embers and a dusting of ridged scales on its cheeks and brow."
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
