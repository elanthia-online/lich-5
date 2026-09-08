{
  schema_version: 3,
  name: "plains orc scout",
  noun: "scout",
  url: "https://gswiki.play.net/plains_orc_scout",
  picture: "",
  level: 17,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 150,
  speed: nil,
  height: 7,
  size: "medium",
  areas: [
    {
      name: "Yegharren Plains",
      uids: [13034101..13034119, 13034201..13034221, 13034301..13034338, 13034401..13034416]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: (157..175)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [
      {
        name: "Throw"
      },
      {
        name: "Lash"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (95..181),
    ranged: (57..88),
    bolt: (57..88),
    udf: (151..219),
    bar_td: (51..57),
    cle_td: (48..57),
    emp_td: (51..59),
    pal_td: (48..57),
    ran_td: (45..51),
    sor_td: (45..54),
    wiz_td: 57,
    mje_td: (51..57),
    mne_td: (51..57),
    mjs_td: (48..66),
    mns_td: (48..66),
    mnm_td: (57..67),
    defensive_spells: [
      "Natural Colors (601)",
      "Self Control (613)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bone-hilted iron longsword",
    "a crude feather talisman",
    "some rough iron-scaled leathers"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "scraggly orc scalp",
    other: "s'ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as a giantman and twice as muscular as most, the plains orc scout is taller and more agile than her more primitive orcish brothers, and judging by the cleverness in her beady yellow eyes, probably quite a bit more intelligent as well. Leathery brown skin covers her bulging limbs, the same color as the crude armor that protects her massive torso, and a scraggly red beard frames her heavy jowls."
    ],
    arrival: [
      "A plains orc scout wanders in!",
      "A plains orc scout wanders in looking a bit unsteady on his feet.",
      "A plains orc scout just arrived!",
      "A plains orc scout swaggers in, glances around and nods in approval.",
      "A plains orc scout swaggers in, glances around and rubs {pronoun} claws together in glee.",
      "A plains orc scout swaggers in, glances around and gives off a low rumbling snicker.",
      "A plains orc scout swaggers in, glances around and sneers disdainfully.",
      "A plains orc scout swaggers in, glances around and cackles.",
      "A plains orc scout swaggers in, glances around and shrugs {pronoun} massive shoulders."
    ],
    flee: [
      "A plains orc scout wanders {direction}."
    ],
    death: [
      "A plains orc scout collapses until all that is left is a few scraps of hide.",
      "A plains orc scout jerks one last time and expires."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A plains orc scout traces a glowing sigil in the air!",
      "A plains orc scout closes {pronoun} eyes and gestures at you!",
      "A plains orc scout closes {pronoun} eyes and gestures at {target}!"
    ],
    attacks: {
      attack: [
        "A plains orc scout swings {weapon} at you!",
        "A plains orc scout swings a bone-hilted iron longsword at {target}!"
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
