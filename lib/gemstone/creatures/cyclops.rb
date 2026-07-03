{
  schema_version: 3,
  name: "cyclops",
  noun: "",
  url: "https://gswiki.play.net/cyclops",
  picture: "",
  level: 27,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 350,
  speed: "10",
  height: nil,
  size: "",
  areas: [
    {
      name: "Marshtown",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 238
      },
      {
        name: "Pound (attack)",
        as: 238
      },
      {
        name: "Stomp (attack)",
        as: 238
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
    asg: "11",
    immunities: [],
    melee: 265,
    ranged: nil,
    bolt: 148,
    udf: (190..290),
    bar_td: 84,
    cle_td: 84,
    emp_td: 84,
    pal_td: 84,
    ran_td: 84,
    sor_td: 84,
    wiz_td: 84,
    mje_td: 84,
    mne_td: 84,
    mjs_td: 84,
    mns_td: 84,
    mnm_td: 84,
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
    skin: "a cyclops eye",
    other: "no"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Towering twice the height of the tallest giantman, the cyclops myopically observes the surrounding terrain through its solitary eye.  Aside from these features, the cyclops would appear as any other giantman and is often found wearing animal hides. Blessed with gargantuan strength, the cyclops can wield a 100 pound tree trunk with the same effort that an adventurer wields a dagger.  The cyclops, however, is cursed with poor depth perception, limiting the effect of its attack.  It is not a good practice to tease the cyclops by calling it 'One Eye.'</pre>"
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
