{
  schema_version: 3,
  name: "banshee",
  noun: "",
  url: "https://gswiki.play.net/banshee",
  picture: "",
  level: 50,
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      rooms: []
    },
    {
      name: "Fhorian Village",
      rooms: []
    },
    {
      name: "The Broken Lands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 275
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Scream",
        cs: 230
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: "300 to 421",
    ranged: "221 to 278",
    bolt: 271,
    udf: nil,
    bar_td: 179,
    cle_td: 195,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 204,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 214,
    mjs_td: nil,
    mns_td: 193,
    mnm_td: 150,
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
    other: "[[Inky necrotic core]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Speculated to have been a female wizard or sorcerer, this horrible creature has been bound to life after death by some horrible magic.  Her rotting teeth, decaying flesh, and tattered robes leave little evidence left of her original appearance.  Fading in and out of view, at times you can even see straight through her to the other side!</pre>\n\nAppraisal: <pre{{log2|margin-right=26em}}>The banshee is medium in size and about five feet high in her current state.</pre>"
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
