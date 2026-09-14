{
  schema_version: 3,
  name: "grisly corpse hulk",
  noun: "hulk",
  url: "https://gswiki.play.net/grisly_corpse_hulk",
  picture: "",
  level: 55,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 400,
  speed: 10,
  height: 8,
  size: "large",
  areas: [
    {
      name: "Crawling Shore",
      uids: [4576101..4576126, 4576151..4576160]
    },
    {
      name: "unmapped",
      uids: [4576127..4576150]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Stomp (attack)",
        as: 310
      },
      {
        name: "Closed fist",
        as: 310
      },
      {
        name: "Ensnare",
        as: 326
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Lash"
      }
    ],
    special_abilities: [
      {
        name: "Tremors"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (148..424),
    ranged: (193..276),
    bolt: (193..276),
    udf: (304..469),
    bar_td: nil,
    cle_td: (175..184),
    emp_td: (184..207),
    pal_td: (157..167),
    ran_td: (156..166),
    sor_td: (187..197),
    wiz_td: nil,
    mje_td: 197,
    mne_td: 197,
    mjs_td: (249..255),
    mns_td: (249..255),
    mnm_td: 168,
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
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A grisly corpse hulk is a collection of corpse parts roughly arranged into a humanoid form within a handspan of a giant's height. Milky pinkish fluid drips from the uneven stitches that hold its body together. Its eyes are tiny and appear piggish in such an oversized head. They hold only a rudimentary spark of intellect. \n\nAppraisal:\nThe corpse hulk is large in size, about eight feet high in its current state."
    ],
    arrival: [
      "A grisly corpse hulk trundles in, gurgling grotesquely."
    ],
    flee: [],
    death: [
      "Torn and strained stitches pop all over a grisly corpse hulk's body as it surrenders to death, allowing necrotic organs and ichor to spill free."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A grisly corpse hulk spreads {pronoun} sloughing arms and tries to lock you in a bearhug!",
        "A grisly corpse hulk tries to stomp on you with one massive, rotting foot!",
        "A grisly corpse hulk slams {pronoun} foot down, sending tremors rumbling through the area!",
        "A grisly corpse hulk barrels forward on squat, mismatched legs, flinging {reflexive} at you!"
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
