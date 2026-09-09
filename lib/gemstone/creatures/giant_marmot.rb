{
  schema_version: 3,
  name: "giant marmot",
  noun: "marmot",
  url: "https://gswiki.play.net/giant_marmot",
  picture: "",
  level: 10,
  family: "Rodent",
  type: "Quadruped",
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
  speed: 12,
  height: 1,
  size: "medium",
  areas: [
    {
      name: "Yander's Farm",
      uids: [14005038..14005053]
    },
    {
      name: "Smuggling Tunnels",
      uids: [37002..37041]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 131
      },
      {
        name: "Claw",
        as: (121..131)
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
    melee: (88..117),
    ranged: (78..84),
    bolt: (78..84),
    udf: (76..102),
    bar_td: 30,
    cle_td: 30,
    emp_td: 30,
    pal_td: (27..30),
    ran_td: 30,
    sor_td: 30,
    wiz_td: nil,
    mje_td: 30,
    mne_td: 30,
    mjs_td: 45,
    mns_td: 45,
    mnm_td: 30,
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
    skin: "a marmot pelt",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    stun_break: [
      "A giant marmot staggers as {pronoun} tries to regain {pronoun} bearings!",
      "A giant marmot twitches as {pronoun} tries to regain {pronoun} bearings!"
    ],
    attacks: {
      claw: [
        "A giant marmot claws at you!"
      ],
      bite: [
        "A giant marmot tries to bite you!"
      ]
    },
    stand: [
      "A giant marmot scrambles to {pronoun} feet, baring {pronoun} sharp teeth!"
    ],
    description: [
      "Normally rodents don't grow this big, but these must have been eating something special. The giant marmot is as long as a human is tall. Thick-bodied, with coarse, brown fur and a stubby tail, the giant marmot still moves with amazing speed, zipping around obstacles and through doorways in search of its next meal. Fresh blood and pieces of flesh surrounding its mouth indicate that it's been using its long incisors to gnaw on something that probably didn't wish to be gnawed on."
    ],
    arrival: [],
    flee: [
      "A giant marmot waddles {direction}.",
      "A giant marmot snorfles as {pronoun} slowly backs away."
    ],
    death: [
      "The giant marmot collapses to the ground, emits a final squeal, and dies.",
      "The giant marmot collapses to the ground, emits a final silent squeal, and dies.",
      "The giant marmot twitches and dies.",
      "The giant marmot twitches violently, then dies."
    ],
    decay: [
      "A giant marmot decays into a pile of hair and bone."
    ],
    search: [
      "A giant marmot sits up on {pronoun} hind legs and peers about."
    ],
    spell_prep: [],
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
