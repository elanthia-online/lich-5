{
  schema_version: 3,
  name: "rotting chimera",
  noun: "",
  url: "https://gswiki.play.net/rotting_chimera",
  picture: "",
  level: 46,
  family: "Chimeric",
  type: "Quadruped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marsh Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 276
      },
      {
        name: "Claw",
        as: 276
      },
      {
        name: "Pound",
        as: 276
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Scorpion Stinger"
      },
      {
        name: "Webbing"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 188,
    ranged: nil,
    bolt: 188,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 161,
    pal_td: nil,
    ran_td: 112,
    sor_td: (167..185),
    wiz_td: nil,
    mje_td: 183,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: 138,
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
    skin: "a chimera stinger",
    other: nil
  },
  messaging: {
    description: [
      "The twisted and confused form of the rotting chimera is a testament to the sacrilege of mortals trying to wield the power of the gods.  While its body looks to be primarily formed of a huge jaguar carcass, the degraded nature of the chimera does little to hide the disfigured appearance of a creature crafted from the parts of many beasts.  Scales disperse into ragged patches of fur that thin out into dangling flesh.  An enormous humanoid arm extends from one of the front shoulder blades of the beast while beneath it, her four legs are borrowed appendages from as many species.  A huge scorpion tail rises high from the rear of the chimera, ready to strike.  Sorrow-ridden eyes, one slitted, the other round, gaze into the distance as an uneven tempo of labored wheezing fills the fetid air.\n\n<small><i>There are two types of rotting chimera.  The above description is for the chimeras that have scorpion tails.  For the webbing chimeras, the \"A huge scorpion tail rises high from the rear of the chimera, ready to strike.\" line is replaced with:</i></small>\n\nThe swollen abdomen of a mammoth arachnid has been grafted to the hind-quarters of the the chimera."
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
