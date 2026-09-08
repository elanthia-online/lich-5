{
  schema_version: 3,
  name: "translucent kiramon strandweaver",
  noun: "strandweaver",
  url: "https://gswiki.play.net/translucent_kiramon_strandweaver",
  picture: "",
  level: 110,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 327,
  speed: nil,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "The Hive",
      uids: [13041201..13041230, 13041301..13041329]
    },
    {
      name: "unmapped",
      uids: [13041330..13041330]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Barbed stinger",
        as: 565
      },
      {
        name: "Bladed forelegs",
        as: 519
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Empathic Link (1117)"
      }
    ],
    offensive_spells: [
      {
        name: "Web (118)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: nil,
    ranged: (517..628),
    bolt: (517..628),
    udf: 600,
    bar_td: nil,
    cle_td: (492..501),
    emp_td: 501,
    pal_td: (456..465),
    ran_td: (468..477),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Empathic Focus (1109)",
      "Strength of Will (1119)"
    ],
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
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "a pallid strandweaver spinnere",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glistening as if moist, the carapace of the kiramon strandweaver is ghost-pale and translucent in places, revealing pulsating organs and fluid-filled sacs quivering beneath. The strandweaver is around the size of a halfling, her undersized body supported by six segmented legs. Her abdomen tapers toward a pair of spinnerets aglisten with prismatic threads of spent webbing."
    ],
    arrival: [
      "The faint, unearthly glow wicking off of a translucent kiramon strandweaver's translucent carapace precedes her as she crawls in uncertainly, antennae twitching.",
      "A translucent kiramon strandweaver skitters in awkwardly, hunching over {pronoun} wounds.",
      "A translucent kiramon strandweaver scuttles in, {pronoun} wounds aglow with restorative ichor."
    ],
    flee: [],
    death: [
      "A translucent kiramon strandweaver collapses to the ground, her ghostly pale legs kicking spastically before abruptly stilling as she dies."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A translucent kiramon strandweaver concentrates intently on you, and a pulse of pearlescent energy ripples toward you!"
    ],
    stand: [
      "A translucent kiramon strandweaver twists {pronoun} segmented abdomen, rolling onto {pronoun} front so that {pronoun} can rise to {pronoun} full height once more."
    ],
    attacks: {
      attack: [
        "A translucent kiramon strandweaver twists grotesquely, aiming {pronoun} spinnerets at you before shooting a clot of thick webbing!",
        "A translucent kiramon strandweaver twitches {pronoun} antennae as {pronoun} focuses upon you!",
        "A translucent kiramon strandweaver sprays an intricate mesh of clinging gossamer at you!",
        "A translucent kiramon strandweaver concentrates for a moment while staring intently at you."
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
