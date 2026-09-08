{
  schema_version: 3,
  name: "hisskra chieftain",
  noun: "chieftain",
  url: "https://gswiki.play.net/hisskra_chieftain",
  picture: "",
  level: 34,
  family: "Hisskra",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 300,
  speed: 8,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Ruined Tower",
      uids: [305001..305022]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dart",
        as: 260
      },
      {
        name: "Trident",
        as: 235
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tail Swipe"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (152..330),
    ranged: (147..171),
    bolt: (147..171),
    udf: 266,
    bar_td: 105,
    cle_td: (116..125),
    emp_td: (117..124),
    pal_td: (99..102),
    ran_td: (102..111),
    sor_td: (123..132),
    wiz_td: nil,
    mje_td: (123..132),
    mne_td: (123..132),
    mjs_td: (117..126),
    mns_td: (117..126),
    mnm_td: (102..108),
    defensive_spells: [],
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
    skin: "hisskra crest",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "As tall as a typical human, the humanoid reptilian hisskra shares many characteristics with mankind. A long snout filled with an array of sharp teeth dominates the hisskra's facial features, giving him the appearance of a bipedal, ruby-crested iguana. Well-defined pectorals and a muscular torso are nearly man-like, but for the dull, dark green scales that fade to a paler shade at the throat, and the ridge of boney, red-tinged spines that runs from between the hisskra chieftain's shoulder blades to the tip of his five-foot tail. The hisskra's muscular limbs end in thick-fingered, partially-webbed hands and feet tipped with blackened claws, which are formidable weapons should the creature lose his more civilized martial implements. A glint of cunning is revealed in the depths of the hisskra chieftain's eyes as he peers about, his tongue flicking over his scaly lips."
    ],
    arrival: [
      "A hisskra chieftain stalks in, gripping his slimy trident menacingly!",
      "A hisskra chieftain leaps in, screaming a reptilian challenge!"
    ],
    flee: [
      "A hisskra chieftain bounds {direction}."
    ],
    death: [
      "The hisskra chieftain rolls over on his back and dies.",
      "The hisskra chieftain twitches violently, then dies.",
      "The hisskra chieftain collapses in a motionless heap.",
      "The hisskra chieftain contorts in a tortured spasm, then goes still.",
      "The hisskra chieftain twitches violently in his death throes before finally going still.",
      "A hisskra chieftain collapses into a putrid lump of scaly flesh."
    ],
    decay: [
      "A hisskra chieftain decays into a pile of scales and bone.",
      "A hisskra chieftain withers away, leaving nothing but a few scales that blow away on a gentle breeze.",
      "A hisskra chieftain collapses into a putrid lump of scaly flesh.",
      "A raging hisskra chieftain collapses into a putrid lump of scaly flesh.",
      "A hisskra chieftain's scales wither as {pronoun} decays into dust."
    ],
    search: [],
    spell_prep: [
      "A hisskra chieftain hisses fearfully as {pronoun} slowly backs away, seeking an avenue for escape."
    ],
    stun_break: [
      "A hisskra chieftain staggers, moving unsteadily as {pronoun} tries to regain {pronoun} bearings."
    ],
    attacks: {
      attack: [
        "A hisskra chieftain swings {weapon} at you!",
        "A hisskra chieftain shoots a tiny dart at you!",
        "A hisskra chieftain springs to {pronoun} feet!",
        "A hisskra chieftain lashes {pronoun} tail out at your legs with lightning speed!"
      ],
      claw: [
        "A hisskra chieftain claws blindly at the air in front of {pronoun} as {pronoun} tries to regain {pronoun} bearings!"
      ],
      hurl: [
        "A hisskra chieftain throws {weapon} at you!"
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
