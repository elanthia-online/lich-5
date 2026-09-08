{
  schema_version: 3,
  name: "Vvrael destroyer",
  noun: "destroyer",
  url: "https://gswiki.play.net/vvrael_destroyer",
  picture: "",
  level: 108,
  family: "Vvrael",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: false,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Anti-mana"
  ],
  bcs: true,
  max_hp: 345,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Rift",
      uids: [4571001..4571030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claidhmore",
        as: (450..469)
      },
      {
        name: "Maul",
        as: (450..470)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Mighty Blow"
      },
      {
        name: "Sunder Shield"
      },
      {
        name: "Tackle"
      },
      {
        name: "Warcry"
      },
      {
        name: "Weapon Bonding"
      },
      {
        name: "Lash"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "20",
    immunities: [],
    melee: nil,
    ranged: (246..426),
    bolt: (246..426),
    udf: (424..769),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crackling black steel maul",
    "some acid-pitted black steel full plate"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A Vvrael destroyer can be found in the Scatter in the Rift. This is a greater servant of the Vvrael, sent to dispatch the strongest of their foes. These are warrior type creatures; very powerful and highly destructive.\n\nA strong jawline and shrewd, narrowed eyes are prominent in the features of the Vvrael destroyer's countenance, creating of his mouth a severe line and of his gaze an openly vicious stare. All the malice caught in the creature's eyes make promises to be answered by the muscular, though ephemeral physique obvious even below his segmented pieces of armor. Despite the bulk of his form, the destroyer moves with the militant grace of a seasoned warrior, precise and purposeful."
    ],
    arrival: [
      "A Vvrael destroyer strides in!",
      "A Vvrael destroyer just arrived!"
    ],
    flee: [
      "A Vvrael destroyer strides {direction}."
    ],
    death: [
      "The Vvrael destroyer crumples to the ground motionless.",
      "The body of the destroyer twists and distorts until he shatters and dissipates into aether.",
      "The Vvrael destroyer crumples to the floor motionless.",
      "The Vvrael destroyer writhes in black agony and dies.",
      "The Vvrael destroyer wails with rage as he crumples to the ground!  A viscous black liquid sprays out from his severed left leg thrashing on the ground!"
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      tackle: [
        "A Vvrael destroyer hurls {reflexive} at {target}!"
      ],
      attack: [
        "A Vvrael destroyer swings {weapon} at you!",
        "Tightening {pronoun} grip on {pronoun} black steel maul, a Vvrael destroyer strikes out at you with all of {pronoun} might!",
        "A Vvrael destroyer swings a crackling black steel maul at {target}!",
        "A Vvrael destroyer leaps to {pronoun} feet!",
        "A Vvrael destroyer's face contorts as {pronoun} unleashes a gutteral, deep-throated growl at you!"
      ],
      hurl: [
        "A Vvrael destroyer hurls {weapon} at {target}!"
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
