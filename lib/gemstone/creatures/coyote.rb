{
  schema_version: 3,
  name: "coyote",
  noun: "coyote",
  url: "https://gswiki.play.net/coyote",
  picture: "",
  level: 5,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 60,
  speed: 6,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Upper Trollfang",
      uids: [16001..16005, 16011..16013]
    },
    {
      name: "Vornavian Coast",
      uids: [4214101..4214115]
    },
    {
      name: "Lower Dragonsclaw",
      uids: [9042..9047, 9058..9058]
    },
    {
      name: "Plains of Vornavis",
      uids: [4212101..4212130, 4213101..4213130]
    },
    {
      name: "Liath Bheinn and Aillidh Brae",
      uids: [4250022..4250026]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (76..95)
      },
      {
        name: "Charge",
        as: (85..95)
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
    asg: "8N",
    immunities: [],
    melee: (7..54),
    ranged: (12..22),
    bolt: (12..22),
    udf: (53..83),
    bar_td: 15,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 57,
    mns_td: 57,
    mnm_td: 15,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a coyote tail",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The coyote, a quick, buff-colored creature, is a smaller cousin of the wolf. However, the coyote lacks the wolf's braver tendencies, preferring to slash and run rather than risk a frontal assault in an attempt to go for the throat. The coyote must be approached with care, as the coyote has been known to take an adventurer's hand off with one quick snap of the jaws."
    ],
    arrival: [
      "A coyote pads in so quietly that you barely notice."
    ],
    flee: [
      "A coyote pads {direction}.",
      "A coyote whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The coyote falls to the ground and dies.",
      "The coyote rolls over and dies."
    ],
    decay: [
      "A coyote decays into a compost of fangs and fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A coyote shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A coyote charges at you!"
      ],
      bite: [
        "A coyote tries to bite you!"
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
