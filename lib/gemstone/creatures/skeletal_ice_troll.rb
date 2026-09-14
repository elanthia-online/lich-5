{
  schema_version: 3,
  name: "skeletal ice troll",
  noun: "troll",
  url: "https://gswiki.play.net/skeletal_ice_troll",
  picture: "",
  level: 31,
  family: "Troll",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead",
    "Element-based"
  ],
  bcs: true,
  max_hp: 360,
  speed: 8,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Ice Plains",
      uids: [7502011..7502015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Battle axe",
        as: 205
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 183
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "16",
    immunities: [],
    melee: (64..96),
    ranged: (64..87),
    bolt: (64..87),
    udf: (158..183),
    bar_td: nil,
    cle_td: 93,
    emp_td: 93,
    pal_td: (90..93),
    ran_td: 93,
    sor_td: 93,
    wiz_td: nil,
    mje_td: 93,
    mne_td: 93,
    mjs_td: 93,
    mns_td: 93,
    mnm_td: 93,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a badly torn rusted chain hauberk",
    "an enruned ice-covered battle axe"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: nil,
    other: "essence of water",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Huge, massive and dangerous, the Troll towers above even a tall Giantman. Grey skin so thick that it serves quite well as armor covers most of the monster with here and there tufts of thick hair sprouting like weeds between cracked paving stones. A hideous grin splits its face displaying for you fangs crusted with dried blood and less guessable matter. No light of intellect glows in its piggish, narrow eyes. Lust of slaughter and a thirst for blood and mortal flesh are all that animate this hulkish beast."
    ],
    arrival: [
      "A skeletal ice troll just arrived."
    ],
    flee: [
      "A skeletal ice troll runs {direction}."
    ],
    death: [
      "The ice troll falls to the ground motionless.",
      "The ice troll screams evilly one last time and goes still."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A skeletal ice troll gestures at you!",
        "A skeletal ice troll swings {weapon} at you!"
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
