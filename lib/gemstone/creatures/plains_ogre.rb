{
  schema_version: 3,
  name: "plains ogre",
  noun: "",
  url: "https://gswiki.play.net/plains_ogre",
  picture: "",
  level: 17,
  family: "Ogre",
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
  max_hp: 220,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Grasslands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 165
      },
      {
        name: "Mace",
        as: 175
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (77..85),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 51,
    cle_td: nil,
    emp_td: 51,
    pal_td: nil,
    ran_td: nil,
    sor_td: 51,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 51,
    mjs_td: 51,
    mns_td: 51,
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre nose",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Even while slightly hunched over, the plains ogre is taller than any giantman.  Long-limbed and lithe for rapid travel over the plains, his body is the antithesis of most of his cousins.  The one exception is in his massive hands that can easily crush anything unlucky enough to be in caught in their grasp.  The plains ogre's face is pinched in a permanent squint from countless hours out on the sun-baked plains.  When standing downwind of this creature, it is evident that he is in much need of a bath.</pre>"
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
