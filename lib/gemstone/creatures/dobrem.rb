{
  schema_version: 3,
  name: "dobrem",
  noun: "dobrem",
  url: "https://gswiki.play.net/dobrem",
  picture: "",
  level: 28,
  family: "Canine",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "pack",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 242,
  speed: nil,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Outlands",
      uids: [2152003..2152029, 4215100..4215118, 4215133..4215160, 4215164..4215182]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite"
      },
      {
        name: "Claw",
        as: (198..249)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Canine lunge"
      },
      {
        name: "Lunge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (140..195),
    ranged: (128..153),
    bolt: (128..154),
    udf: 172,
    bar_td: 84,
    cle_td: 84,
    emp_td: (76..84),
    pal_td: 84,
    ran_td: 84,
    sor_td: 84,
    wiz_td: 84,
    mje_td: 84,
    mne_td: 84,
    mjs_td: 84,
    mns_td: 84,
    mnm_td: 84,
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
    skin: "a dobrem snout",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The dobrem is a dog of medium size, with a body that is square, compactly built, muscular and powerful. The fierce animal is elegant in appearance, of proud carriage, reflecting great nobility. Almost three feet tall at the shoulders, the dobrem is covered by short black fur with sharply defined rust coloured markings appearing about each eye and on muzzle, throat and forechest, on all legs and feet and below the tail."
    ],
    arrival: [],
    flee: [
      "A dobrem lopes {direction}!",
      "A dobrem whimpers as {pronoun} slowly backs away, {pronoun} teeth bared."
    ],
    death: [
      "The dobrem falls to the ground and dies.",
      "The dobrem rolls over and dies."
    ],
    decay: [
      "A dobrem decays into a compost of fangs and fur."
    ],
    search: [],
    spell_prep: [],
    stun_break: [
      "A dobrem shakes {pronoun} head violently while trying to regain {pronoun} bearings!"
    ],
    attacks: {
      attack: [
        "A dobrem lunges at you!"
      ],
      claw: [
        "A dobrem claws at you!"
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
