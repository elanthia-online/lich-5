{
  schema_version: 3,
  name: "lesser red orc",
  noun: "orc",
  url: "https://gswiki.play.net/lesser_red_orc",
  picture: "",
  level: 7,
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
  max_hp: 100,
  speed: 12,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [68001..68004, 68010..68016]
    },
    {
      name: "Yander's Farm",
      uids: [14005023..14005025, 14005027..14005036]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scimitar",
        as: (99..111)
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
    asg: "9",
    immunities: [],
    melee: (39..107),
    ranged: (24..34),
    bolt: (24..34),
    udf: (49..114),
    bar_td: 21,
    cle_td: 21,
    emp_td: 21,
    pal_td: (18..21),
    ran_td: 21,
    sor_td: 21,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
    mjs_td: 21,
    mns_td: 21,
    mnm_td: 21,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a leather breastplate",
    "a leather helm",
    "a reinforced shield",
    "a scimitar"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a red orc scalp",
    other: nil,
    armaments: [
      "steel-banded shield"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Erect, the red orc would stand approximately six feet high. However, her hunched shoulders and curved spine bring her head nearly two feet closer to the ground. Thick, matted, deep burgundy fur covers most of the orc's body, probably accounting for the red name applied to her. Her muzzle protrudes from the bony cranium, and her lips seem to be constantly pulled back to reveal pointed, discolored fangs. The evil smile goes well with the malevolent yellow eyes behind it."
    ],
    arrival: [],
    flee: [
      "A lesser red orc spins about and then runs {direction}.",
      "A lesser red orc lopes {direction}.",
      "A lesser red orc shambles out from the shadows.",
      "A lesser red orc begins to retreat backwards as {pronoun} gazes about through bloodshot eyes."
    ],
    death: [
      "A lesser red orc collapses in a red mess and dies.",
      "A lesser red orc collapses into dust."
    ],
    decay: [
      "A lesser red orc collapses into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser red orc swings {weapon} at you!",
        "A lesser red orc thrusts {pronoun} scimitar out in front of {pronoun}."
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
