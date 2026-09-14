{
  schema_version: 3,
  name: "plumed cockatrice",
  noun: "cockatrice",
  url: "https://gswiki.play.net/plumed_cockatrice",
  picture: "",
  level: 13,
  family: "Basilisk",
  type: "Hybrid",
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
  max_hp: 123,
  speed: 11,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Neartofar Forest",
      uids: [14015001..14015020]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge",
        as: 167
      },
      {
        name: "Claw",
        as: 157
      },
      {
        name: "Pincer (attack)",
        as: 157
      },
      {
        name: "Strike",
        as: 143
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Dust Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (111..197),
    ranged: (89..119),
    bolt: 67,
    udf: (124..212),
    bar_td: nil,
    cle_td: (39..45),
    emp_td: (31..39),
    pal_td: (33..42),
    ran_td: 9,
    sor_td: (39..45),
    wiz_td: nil,
    mje_td: (39..42),
    mne_td: (39..42),
    mjs_td: 60,
    mns_td: 60,
    mnm_td: (33..39),
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
    skin: "a cockatrice plume",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A smaller relative of the basilisk, the plumed cockatrice has a snake-like body, plumes of feathers spearing up from its head, dapple grey wings, and short, stout legs. Its cold, penetrating gaze is not nearly as deadly as that of its larger cousin but the plumed cockatrice should not be treated lightly. Its vicious use of its sharp beak and raking claws make it a fierce opponent even in the best of situations."
    ],
    arrival: [
      "A plumed cockatrice just arrived!"
    ],
    flee: [
      "A plumed cockatrice thunders {direction}."
    ],
    death: [
      "The plumed cockatrice rolls over on its back, emits a final screech and dies."
    ],
    decay: [
      "A plumed cockatrice decays into a useless pile of scales and feathers."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A plumed cockatrice screeches and strikes at you!",
        "A plumed cockatrice attempts to kick dust at you, but is unable to kick up a sufficient amount of dust.",
        "A plumed cockatrice screeches as {pronoun} stares hatefully at you."
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
