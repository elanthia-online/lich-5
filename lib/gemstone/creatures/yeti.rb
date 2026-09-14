{
  schema_version: 3,
  name: "yeti",
  noun: "yeti",
  url: "https://gswiki.play.net/yeti",
  picture: "",
  level: 67,
  family: "Yeti",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 400,
  speed: 7,
  height: 12,
  size: "huge",
  areas: [
    {
      name: "Griffin's Keen",
      uids: [13302101..13302169]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: (347..359)
      },
      {
        name: "Stomp",
        as: (289..347)
      },
      {
        name: "Monstrous hairy hand",
        as: 312
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground Slap"
      },
      {
        name: "Hurl Boulder (510)"
      },
      {
        name: "Stomp"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (357..465),
    ranged: (243..303),
    bolt: (243..303),
    udf: (376..565),
    bar_td: (226..247),
    cle_td: (251..257),
    emp_td: (256..265),
    pal_td: (216..222),
    ran_td: 219,
    sor_td: (266..275),
    wiz_td: nil,
    mje_td: (283..285),
    mne_td: (283..285),
    mjs_td: (247..256),
    mns_td: (247..256),
    mnm_td: (200..209),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "A yeti roars in anger and shakes off the stun."
    ],
    attacks: {
      attack: [
        "A yeti raises {pronoun} hairy foot and attempts to stomp you into the ground!",
        "A yeti swings {weapon} at you!",
        "A yeti swings {pronoun} arms together in an attempt to trap you! You scramble back out of the way of its lumbering hug.",
        "A yeti swings {pronoun} {weapon}! You scrabble out of the way of its lumbering hug.",
        "A yeti swings {pronoun} arms together in an attempt to trap you! You scrabble out of the way of its lumbering hug."
      ]
    },
    stand: [
      "A yeti rises to {pronoun} feet and gives a shudder, flinging hair everywhere."
    ],
    description: [
      "Standing almost twelve feet tall, the yeti is a large humanoid creature covered in long, stringy black and red hair. His domed pate is matted with twigs and dirt, and his heavy brow forms a shelf over his tiny black eyes. With arms nearly long enough to brush the ground, the yeti has a ferociously strong grip and excellent leverage for the tossing of heavy objects. Broad, flat feet provide stability and traction in the icy, mountainous environments that are his normal habitat."
    ],
    arrival: [
      "A giant shadow towers over the area as a yeti stomps in!",
      "A yeti stomps in!",
      "A yeti moans as it stomps in!",
      "A yeti roars in pain as it stomps in!",
      "A yeti just arrived.",
      "A giant shadow darkens the room as a yeti stomps in!",
      "A keen yeti stomps in!"
    ],
    flee: [
      "A yeti spins around and retreats as far as it can.",
      "A yeti stomps {direction}.",
      "A yeti moans as it stomps {direction}.",
      "A yeti roars in pain as it stomps {direction}.",
      "A canny yeti stomps {direction}."
    ],
    death: [
      "The mass of hair and bone that was the yeti finally goes still.",
      "The yeti collapses into a pile of hair and bones and goes still."
    ],
    decay: [
      "The yeti collapses into a pile of hair and bones and goes still.",
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
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
