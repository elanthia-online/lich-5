{
  schema_version: 3,
  name: "snowy cockatrice",
  noun: "cockatrice",
  url: "https://gswiki.play.net/snowy_cockatrice",
  picture: "",
  level: 6,
  family: "Basilisk",
  type: "Hybrid",
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
  max_hp: 69,
  speed: 30,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Southern Snowfields",
      uids: [4128045..4128055]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 109
      },
      {
        name: "Claw",
        as: 99
      },
      {
        name: "Pincer (attack)",
        as: 99
      },
      {
        name: "Strike",
        as: 99
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Stare"
      },
      {
        name: "Dust Kick"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (33..109),
    ranged: (27..40),
    bolt: (27..40),
    udf: (63..134),
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "snowy cockatrice tailfeather",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A smaller relative of the basilisk, the cockatrice has a serpentine body, with feathered head, wings, and legs. Having the cold, freezing gaze of its larger cousin, the cockatrice should not be treated lightly. A sharp beak and raking claws complete this small but deadly package of evil."
    ],
    arrival: [
      "A snowy cockatrice just arrived!"
    ],
    flee: [
      "A snowy cockatrice thunders {direction}."
    ],
    death: [
      "The snowy cockatrice rolls over on its back, emits a final screech and dies."
    ],
    decay: [
      "A snowy cockatrice decays into a useless pile of scales and feathers."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A snowy cockatrice screeches and strikes at you!",
        "A snowy cockatrice attempts to kick dust at you, but is unable to kick up a sufficient amount of dust.",
        "A snowy cockatrice screeches as {pronoun} stares hatefully at you."
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
