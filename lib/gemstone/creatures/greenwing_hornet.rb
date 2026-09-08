{
  schema_version: 3,
  name: "greenwing hornet",
  noun: "hornet",
  url: "https://gswiki.play.net/greenwing_hornet",
  picture: "",
  level: 18,
  family: "Wasp",
  type: "Insect",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 165,
  speed: 5,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Castle Anwyn",
      uids: [4285036..4285040, 4285043..4285047, 4285051..4285057]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stinger (attack)",
        as: 172
      },
      {
        name: "Stinger",
        as: 172
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Sting"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (128..142),
    ranged: 130,
    bolt: (120..130),
    udf: 140,
    bar_td: nil,
    cle_td: 54,
    emp_td: 54,
    pal_td: (51..54),
    ran_td: nil,
    sor_td: 54,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
    mjs_td: 100,
    mns_td: 100,
    mnm_td: 54,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a completely severed left leg"
  ],
  treasure: {
    coins: true,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a hornet stinger",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "If it wasn't for the huge size of this hornet, you might even call it kinda cute. The fuzzy body measures about 8 inches long and almost that big around. The wings are moving so fast that it seems as though the hornet is surrounded with a faint green haze. Darting here and there, with an agility astonishing in something this pudgy looking, it's enough to make one think twice before getting too close!"
    ],
    arrival: [],
    flee: [],
    death: [
      "The greenwing hornet falls back into a heap and dies.",
      "The greenwing hornet flutters its wings one last time and dies."
    ],
    decay: [
      "A greenwing hornet decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A greenwing hornet stabs at you with {pronoun} stinger!"
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
    triggers: {}
  }
}
