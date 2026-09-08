{
  schema_version: 3,
  name: "desiccated half-krolvin strigoi",
  noun: "strigoi",
  url: "https://gswiki.play.net/desiccated_half-krolvin_strigoi",
  picture: "",
  level: 61,
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
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Crawling Shore",
      uids: [4576101..4576126, 4576151..4576160]
    },
    {
      name: "unmapped",
      uids: [4576127..4576150]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist"
      },
      {
        name: "Ensnare (attack)"
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Vampire bite?"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (348..353),
    ranged: (170..272),
    bolt: (170..272),
    udf: (383..508),
    bar_td: nil,
    cle_td: (222..225),
    emp_td: (222..225),
    pal_td: (180..189),
    ran_td: 183,
    sor_td: (227..236),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 260,
    mns_td: 260,
    mnm_td: (177..183),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some tattered hide clothing adorned with bone buttons"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The corpse-like face of the half-krolvin strigoi bears little resemblance to a living half-krolvin save in its heavy brow and dense brows. Eyes like pits of shadow stare out from the sunken hollows of the strigoi's altered visage, hungry and hateful. The strigoi has yellowed fangs that distend her lips in an ugly fashion. Her motions are distinctly unnatural, fluid in a way that a living being's are not. \n\nAppraisal:\nThe half-krolvin strigoi is medium in size, about six feet high in her current state."
    ],
    arrival: [
      "A desiccated half-krolvin strigoi crawls in, {pronoun} body low to the ground.",
      "A desiccated half-krolvin strigoi crawls in, his featureless black eyes gleaming predatorily in the ambient light.  He bares his yellowed fangs, insatiable hunger twisting his face.",
      "A desiccated half-krolvin strigoi crawls in, her featureless black eyes gleaming predatorily in the ambient light.  She bares her yellowed fangs, insatiable hunger twisting her face."
    ],
    flee: [
      "A desiccated half-krolvin strigoi crawls {direction}, {pronoun} body low to the ground."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A desiccated half-krolvin strigoi flings {pronoun} arms wide and throws himself at you, trying to trap you in a deadly embrace!",
        "A desiccated half-krolvin strigoi raises a clawed hand overhead and slashes viciously at you!",
        "A desiccated half-krolvin strigoi leaps up from the ground and lands in an animalistic crouch."
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
