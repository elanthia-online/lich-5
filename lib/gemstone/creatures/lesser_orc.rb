{
  schema_version: 3,
  name: "lesser orc",
  noun: "orc",
  url: "https://gswiki.play.net/lesser_orc",
  picture: "",
  level: 6,
  family: "Orc",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 88,
  speed: 15,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Melgorehn's Valley",
      uids: [2148002..2148024]
    },
    {
      name: "Old Mine Road",
      uids: [20001..20018]
    },
    {
      name: "Upper Trollfang",
      uids: [15001..15034]
    },
    {
      name: "Southern Snowfields",
      uids: [4128031..4128042]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 108
      },
      {
        name: "Short sword",
        as: (88..108)
      },
      {
        name: "Unknown",
        as: 108
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
    asg: nil,
    immunities: [],
    melee: (36..114),
    ranged: (29..37),
    bolt: (29..37),
    udf: (63..127),
    bar_td: 18,
    cle_td: 18,
    emp_td: 18,
    pal_td: (15..18),
    ran_td: 18,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: 18,
    mns_td: 18,
    mnm_td: 18,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a cudgel",
    "a flail",
    "a leather breastplate",
    "a leather helm",
    "a metal aventail",
    "a reinforced shield",
    "a short sword",
    "a wooden shield",
    "some full leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an orc hide",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The lesser orc stands almost man high but is much thicker so that it appears stunted for its height. Heavy brow ridges and a sloping forehead give the beast a brutish appearance not aided by its rank breath and foul odor. It glares blankly around ignoring anything that it can't eat or pillage."
    ],
    arrival: [
      "A lesser orc wanders in looking a bit unsteady on {pronoun} feet."
    ],
    flee: [
      "A lesser orc tramps {direction}.",
      "A lesser orc wobbles slightly and then heads {direction}."
    ],
    death: [
      "A lesser orc screams one last time and dies.",
      "A lesser orc screams silently one last time and dies.",
      "A lesser orc's looks dazed and confused.  The orc stumbles and slumps to the ground!"
    ],
    decay: [
      "A small, green cloud of smelly gas rises from the body of a kobold as he decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A lesser orc swings {weapon} at you!",
        "A lesser orc swings a short sword at {target}!",
        "A lesser orc swings a cudgel at {target}!"
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
