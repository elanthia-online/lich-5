{
  schema_version: 3,
  name: "warrior shade",
  noun: "shade",
  url: "https://gswiki.play.net/warrior_shade",
  picture: "",
  level: 48,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: false,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Non-corporeal undead",
    "Boss"
  ],
  bcs: nil,
  max_hp: 300,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Fethayl Bog",
      uids: [13038001..13038031]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Halberd",
        as: (253..325)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Disarm Weapon"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "13N",
    immunities: [],
    melee: (201..233),
    ranged: (175..215),
    bolt: (175..215),
    udf: 311,
    bar_td: 158,
    cle_td: 176,
    emp_td: (172..181),
    pal_td: (149..158),
    ran_td: 149,
    sor_td: (185..194),
    wiz_td: nil,
    mje_td: (195..196),
    mne_td: (195..196),
    mjs_td: (174..178),
    mns_td: (174..178),
    mnm_td: (144..153),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a twisted modwir-shafted halberd"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glowing violet essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "But a shadow of its former self, the warrior shade's form is hardly discernable as it flickers in and out of view. At times strange ripples of ethereal light roll across its spectral image, highlighting every horrible scar and festering wound on the shade's translucent body. Its gaunt face stares out from under a ghostly helm, though nothing but deep, hollow pits for eyes can be seen, soulless and unforgiving in their regard."
    ],
    arrival: [
      "A warrior shade just arrived.",
      "A warrior shade strides out of the surrounding mist!"
    ],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A warrior shade swings {weapon} at you!",
        "A warrior shade swings a twisted modwir-shafted halberd at {target}!"
      ]
    },
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
    triggers: {},
    frenzy: "A warrior shade whales away, consumed with bloodlust!"
  }
}
