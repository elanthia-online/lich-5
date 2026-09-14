{
  schema_version: 3,
  name: "lesser construct",
  noun: "construct",
  url: "https://gswiki.play.net/lesser_construct",
  picture: "",
  level: 83,
  family: "Golem",
  type: "Biped",
  undead: false,
  blood: false,
  bones: false,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Magical"
  ],
  bcs: true,
  max_hp: 534,
  speed: 9,
  height: 17,
  size: "huge",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17002201..17002247, 17002301..17002325, 17003011..17003038, 17003101..17003150]
    },
    {
      name: "unmapped",
      uids: [17003001..17003010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flail"
      },
      {
        name: "Stomp",
        as: 404
      },
      {
        name: "Massive arm",
        as: (404..424)
      },
      {
        name: "Smash",
        as: (404..416)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Foot Stomp"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "19",
    immunities: ["magic"],
    melee: (176..510),
    ranged: (160..328),
    bolt: (160..328),
    udf: (391..640),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
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
    other: "crystal core",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The white granite-like features of the lesser construct hold no hints of the giant creature's intentions or motivations. Its alabaster skin made more of the hardest rock than any living tissue makes the construct a formidable opponent for any who dare to trifle with it. Massing more than ten giantmen, it is a a mountain of rock when in motion and very little, man or animal can oppose its desired path of travel once it is in motion."
    ],
    arrival: [
      "A lesser construct lumbers in!"
    ],
    flee: [
      "A lesser construct crawls {direction}.",
      "A lesser construct grumbles as it heads {direction}."
    ],
    death: [
      "The lesser construct collapses, {pronoun} eyes fading to a lifeless gaze and stone shell cracking into a barely discernible form."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser construct raises {pronoun} massive foot and attempts to smash you!",
        "A lesser construct swings {weapon} at you!",
        "A lesser construct swings {pronoun} arms together in an attempt to trap you! You scramble back out of the way of {pronoun} lumbering hug.",
        "A lesser construct swings {pronoun} arms together in an attempt to trap you! You scramble back out of the way of its lumbering hug."
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
