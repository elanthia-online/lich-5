{
  schema_version: 3,
  name: "rotting farmhand",
  noun: "farmhand",
  url: "https://gswiki.play.net/rotting_farmhand",
  picture: "",
  level: 32,
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
  max_hp: 300,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Abandoned Farm",
      uids: [4124114..4124124]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Rusted pitchfork",
        as: 243
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
    asg: "5",
    immunities: [],
    melee: (208..369),
    ranged: (201..211),
    bolt: (201..211),
    udf: 246,
    bar_td: 105,
    cle_td: (97..106),
    emp_td: (108..116),
    pal_td: (93..102),
    ran_td: (96..105),
    sor_td: (109..112),
    wiz_td: nil,
    mje_td: (114..115),
    mne_td: (114..115),
    mjs_td: (104..113),
    mns_td: (104..113),
    mnm_td: (93..96),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a ragged straw hat",
    "a rusted pitchfork",
    "a torn plaid shirt",
    "some threadbare coveralls"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "At one time the rotting farmhand would have chosen to be left alone. Now she seeks the company of the living, if only for the short time it takes for her to kill them. Her clothes hang in tatters, waving gently in the breeze as she stumbles about on decaying legs, her putrid flesh barely adhering to her bones. In life the rotting farmhand raised fields of living things. Now her mission seems to be one of filling fields with dead things."
    ],
    arrival: [
      "A rotting farmhand shambles in!"
    ],
    flee: [
      "A rotting farmhand shambles {direction}.",
      "A rotting farmhand wails madly as {pronoun} limps {direction}."
    ],
    death: [
      "The rotting farmhand twitches violently, then dies.",
      "The rotting farmhand wails in terrifying pain one last time and lies still."
    ],
    decay: [
      "A rotting farmhand rots away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A rotting farmhand swings {weapon} at you!",
        "A rotting farmhand swings a rusted pitchfork at {target}!"
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
