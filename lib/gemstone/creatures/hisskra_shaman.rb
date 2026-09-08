{
  schema_version: 3,
  name: "hisskra shaman",
  noun: "shaman",
  url: "https://gswiki.play.net/hisskra_shaman",
  picture: "",
  level: 33,
  family: "Hisskra",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Ruined Tower",
      uids: [305001..305022, 305050..305056]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trident",
        as: (208..222)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 165
      },
      {
        name: "Mana Disruption (702)",
        cs: 165
      }
    ],
    offensive_spells: [
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (172..304),
    ranged: (168..209),
    bolt: (168..209),
    udf: 225,
    bar_td: 112,
    cle_td: 119,
    emp_td: (121..131),
    pal_td: (101..110),
    ran_td: (95..101),
    sor_td: (128..144),
    wiz_td: nil,
    mje_td: (131..135),
    mne_td: (131..135),
    mjs_td: (129..139),
    mns_td: (129..139),
    mnm_td: (106..115),
    defensive_spells: [
      "Natural Colors",
      "Resist Elements",
      "Spirit Defense",
      "Spirit Warding I",
      "Spirit Warding II"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a slimy trident"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "hisskra tooth",
    other: "glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Nearly as tall as a typical human, the humanoid reptilian hisskra shares many characteristics with mankind. A long snout filled with an array of sharp teeth dominates the hisskra's facial features, giving him the appearance of a bipedal iguana. Well-defined pectorals and a muscular torso are nearly man-like, but for the dull, dark green scales that fade to a paler shade at the throat, and the ridge of mottled, boney spines that runs from between the hisskra shaman's shoulder blades to the tip of his four-foot tail. The hisskra's muscular limbs end in thick-fingered, partially-webbed hands and feet tipped with blackened claws, which are formidable weapons should the creature lose his more civilized martial implements. A primitive necklace formed of the bones of various sea creatures hangs around the shaman's neck, signifying his rank."
    ],
    arrival: [],
    flee: [
      "A hisskra shaman creeps {direction}.",
      "A dreary hisskra shaman creeps {direction}.",
      "An afflicted hisskra shaman creeps {direction}."
    ],
    death: [
      "The hisskra shaman rolls over on his back and dies.",
      "The hisskra shaman collapses in a motionless heap.",
      "The hisskra shaman contorts in a tortured spasm, then goes still.",
      "The hisskra shaman twitches violently in his death throes before finally going still.",
      "A hisskra shaman collapses into a putrid lump of scaly flesh."
    ],
    decay: [
      "A hisskra shaman decays into a pile of scales and bone.",
      "A hisskra shaman collapses into a putrid lump of scaly flesh.",
      "A hisskra shaman withers away, leaving nothing but a few scales that blow away on a gentle breeze.",
      "A keen hisskra shaman's scales wither as he decays into dust.",
      "A spindly hisskra shaman decays into a pile of scales and bone.",
      "A hisskra shaman's scales wither as {pronoun} decays into dust."
    ],
    search: [],
    spell_prep: [
      "A hisskra shaman flares {pronoun} throat while hissing an invocation.",
      "A hisskra shaman hisses fearfully as {pronoun} slowly backs away, seeking an avenue for escape."
    ],
    stun_break: [
      "A hisskra shaman staggers, moving unsteadily as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      attack: [
        "A hisskra shaman swings {weapon} at you!",
        "A hisskra shaman utters a single sibilant syllable while raising a clawed hand toward you!"
      ],
      claw: [
        "A hisskra shaman claws blindly at the air in front of {pronoun} as {pronoun} tries to regain {pronoun} bearings!"
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
