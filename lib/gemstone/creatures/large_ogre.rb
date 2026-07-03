{
  schema_version: 3,
  name: "large ogre",
  noun: "",
  url: "https://gswiki.play.net/large_ogre",
  picture: "",
  level: 15,
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
  max_hp: 200,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 145
      },
      {
        name: "Closed fist",
        as: 155
      },
      {
        name: "Flail",
        as: 165
      },
      {
        name: "Two-handed sword",
        as: 165
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
    asg: "location dependent",
    immunities: [],
    melee: (64..77),
    ranged: 70,
    bolt: 52,
    udf: 114,
    bar_td: 45,
    cle_td: 45,
    emp_td: 45,
    pal_td: nil,
    ran_td: nil,
    sor_td: 45,
    wiz_td: 45,
    mje_td: 45,
    mne_td: 45,
    mjs_td: 45,
    mns_td: 45,
    mnm_td: 45,
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
    skin: "ogre tusk",
    other: nil
  },
  messaging: {
    description: [
      "Even while slightly hunched over, the large ogre is taller than any giantman. Heavily muscled, his long arms hang nearly to the ground, ending in massive hands that easily crush anything unlucky enough to be in their grasp. The large ogre squints, as if barely able to see through his long, matted hair or extremely puzzled by the world around him. When standing downwind of this creature, it is evident that a bath is long overdue."
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
