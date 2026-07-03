{
  schema_version: 3,
  name: "wolverine",
  noun: "",
  url: "https://gswiki.play.net/wolverine",
  picture: "",
  level: 24,
  family: "Mustelid",
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
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Northern Mountains",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 234
      },
      {
        name: "Claw"
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
    asg: "11N",
    immunities: [],
    melee: (211..241),
    ranged: nil,
    bolt: nil,
    udf: 225,
    bar_td: 72,
    cle_td: nil,
    emp_td: nil,
    pal_td: 72,
    ran_td: nil,
    sor_td: 79,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 82,
    mjs_td: nil,
    mns_td: 76,
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
    skin: "a wolverine pelt",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Possessed with a ferocious nature far out of proportion to its size, this wolverine appears to be an extremely vicious opponent.  Swift and agile, with claws and teeth backed by muscles like coiled springs, the wolverine will take on and defeat foes three times its size.  Even stout boiled leather is oft times no match for its powerful claws and ferocious bite.  There is commonly a touch of foam about its mouth, which may indicate some type of virulent disease.</pre>"
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
