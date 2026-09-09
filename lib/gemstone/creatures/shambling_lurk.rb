{
  schema_version: 3,
  name: "shambling lurk",
  noun: "lurk",
  url: "https://gswiki.play.net/shambling_lurk",
  picture: "",
  level: 95,
  family: "Zombie",
  type: "Biped",
  undead: true,
  blood: false,
  bones: true,
  limbs: true,
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
  max_hp: 319,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Shadow of the Sanctum",
      uids: [4216001..4216049]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 450
      },
      {
        name: "Bloated arms",
        as: (438..470)
      },
      {
        name: "Strike",
        as: 459
      },
      {
        name: "Bronze cutlass",
        as: (452..533)
      }
    ],
    bolt_spells: [
      {
        name: "Web (118)",
        as: 417
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave"
      }
    ],
    maneuvers: [
      {
        name: "Vomit"
      },
      {
        name: "Bite"
      },
      {
        name: "Gesture"
      },
      {
        name: "Strike"
      },
      {
        name: "Disarm"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (290..584),
    ranged: (318..377),
    bolt: (318..377),
    udf: (428..730),
    bar_td: nil,
    cle_td: (425..434),
    emp_td: (416..422),
    pal_td: (364..367),
    ran_td: (352..386),
    sor_td: 443,
    wiz_td: nil,
    mje_td: (461..465),
    mne_td: (461..465),
    mjs_td: (432..440),
    mns_td: (432..440),
    mnm_td: (276..285),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Animate dead characters",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a case of sporadic convulsions",
    "some rotting sun-bleached garb"
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
      "Not dead so long that its body has begun to lose the unwinnable war against decay, a shambling lurk is firmly in the grip of rigor mortis. Its face is paralyzed in a slack-jawed smile that reveals broken teeth and a dry and swollen tongue. From the viridian firelight dancing in its eyes, it is clear that it is beyond the services of a cleric, except perhaps to grant the blessing of a swift release."
    ],
    arrival: [
      "A shambling lurk just arrived.",
      "Vital fluids seeping from its orifices, a shambling lurk shambles in with a piteous moan.",
      "A shambling lurk totters in with a famished moan.",
      "A shambling lurk just came through a polished acacia archway.",
      "A shambling lurk just came through a pair of high bronze double doors.",
      "A shambling lurk just came through a towering black ora gate."
    ],
    flee: [],
    death: [],
    decay: [
      "Decay rapidly races over a shambling lurk's form as it collapses into foul-smelling compost."
    ],
    search: [
      "A shambling lurk mouths the air hungrily as {pronoun} searches the area."
    ],
    spell_prep: [
      "A shambling lurk moans out a garbled spell."
    ],
    attacks: {
      attack: [
        "A shambling lurk manages a fumbling gesture toward you!",
        "Desperate in {pronoun} hunger for flesh, a shambling lurk throws itself at you!",
        "Gnawing blindly with shattered teeth, a shambling lurk tries to bite into you!",
        "A shambling lurk throws {pronoun} head back and gurgles a single syllable!"
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
