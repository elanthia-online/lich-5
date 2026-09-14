{
  schema_version: 3,
  name: "night mare",
  noun: "mare",
  url: "https://gswiki.play.net/night_mare",
  picture: "",
  level: 43,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: false,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Corporeal undead",
    "Boss"
  ],
  bcs: nil,
  max_hp: 400,
  speed: 8,
  height: 6,
  size: "large",
  areas: [
    {
      name: "Shadow Valley",
      uids: [389030..389035, 2160001..2160035, 2161011..2161022]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (191..226),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 340,
    ran_td: nil,
    sor_td: 161,
    wiz_td: nil,
    mje_td: (474..494),
    mne_td: nil,
    mjs_td: 295,
    mns_td: 295,
    mnm_td: 361,
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
    "a bruised right eye"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a silvery hoof",
    other: "Glowing violet mote of essence",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Eyes glowing green with the hatred of the dead, the night mare's stare bores right through you. A magnificently beautiful equine, the night mare seems to be bathed in a deep green glow that tosses roiling shadows across her coat. Upon closer inspection, shadows can be seen that roil and crawl across its coat much like the nightmares that keep many awake at night. It is said that gazing upon a nightmare for too long will induce waking nightmares that are difficult to shake off."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A night mare flares {pronoun} nostrils."
    ],
    stand: [
      "A night mare throws {pronoun} head back and neighs, shaking off the stun!"
    ],
    attacks: {
      attack: [
        "A night mare snorts at you!"
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
