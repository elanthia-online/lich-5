{
  schema_version: 3,
  name: "snow madrinol",
  noun: "",
  url: "https://gswiki.play.net/snow_madrinol",
  picture: "",
  level: 52,
  family: "Madrinol",
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
      name: "Gossamer Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 301
      },
      {
        name: "Claw",
        as: 311
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tail Sweep"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "15N",
    immunities: [],
    melee: 246,
    ranged: nil,
    bolt: 260,
    udf: nil,
    bar_td: 177,
    cle_td: (184..196),
    emp_td: (188..197),
    pal_td: nil,
    ran_td: nil,
    sor_td: (203..212),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 222,
    mjs_td: (188..197),
    mns_td: 200,
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
    gems: true,
    boxes: nil,
    skin: "a madrinol skin",
    other: "[[Glowing violet essence dust]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The heavily armored snow madrinol moves ponderously through the area searching for easy prey to consume.  Plates of extremely thick slate grey skin cover this quadruped on nearly all its exterior surfaces except its long, leathery tail and cupped, upright ears.  Tufts of off-white fur protrude between the plates, however, giving the impression that the madrinol is wearing pieces of armor rather than a total covering.  Unique to the snow madrinol seems to be its flared, circular hooves.  Sharp claws protrude from all sides of each hoof, allowing the creature to grip the ice or frozen ground for greater stability.</pre>"
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
