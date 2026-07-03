{
  schema_version: 3,
  name: "cave bear",
  noun: "",
  url: "https://gswiki.play.net/cave_bear",
  picture: "",
  level: 21,
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
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Hidden Vale",
      rooms: []
    },
    {
      name: "Troll Lair",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 227
      },
      {
        name: "Bite",
        as: 225
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
    asg: "12N",
    immunities: [],
    melee: (108..163),
    ranged: nil,
    bolt: 96,
    udf: 174,
    bar_td: nil,
    cle_td: 69,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 63,
    wiz_td: nil,
    mje_td: 63,
    mne_td: 63,
    mjs_td: nil,
    mns_td: 63,
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
    boxes: false,
    skin: "bear claw",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The cave bear is one of the smaller breeds of bear, her dark coloration enabling her to conceal herself well in the shadows of cave depths.  She is also one of the fiercest bears, readily defending her chosen territory against all comers.  The cave bear has especially large paws, well-padded to handle the sharp outcroppings and stalagmites of the cave surfaces, but with extremely sharp claws honed on the rough surfaces.  Keen eyesight in low light conditions gives the cave bear an advantage over her intended prey in the caves.</pre>"
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
