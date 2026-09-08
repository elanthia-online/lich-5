{
  schema_version: 3,
  name: "glistening cerebralite",
  noun: "cerebralite",
  url: "https://gswiki.play.net/glistening_cerebralite",
  picture: "",
  level: 100,
  family: "Cerebralite",
  type: "Globoid",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: 2,
  size: "small",
  areas: [
    {
      name: "The Rift",
      uids: [4569001..4569023, 4571001..4571030]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Barbed tentacle",
        as: (176..410)
      },
      {
        name: "Bladed forearms",
        as: 476
      }
    ],
    bolt_spells: [
      {
        name: "Balefire (713)",
        as: 402
      },
      {
        name: "Empathic Assault (1110)",
        as: 402
      },
      {
        name: "Major Shock (910)",
        as: 402
      }
    ],
    warding_spells: [
      {
        name: "Cloak of Shadows (712)",
        cs: 406
      },
      {
        name: "Sympathy (1120)",
        cs: 424
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Song of Depression (1015)"
      },
      {
        name: "Spiritual Abolition (230)"
      }
    ],
    maneuvers: [
      {
        name: "Tail Swipe"
      },
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (339..473),
    ranged: (299..479),
    bolt: (299..479),
    udf: (401..531),
    bar_td: (381..398),
    cle_td: (440..450),
    emp_td: (434..439),
    pal_td: (380..390),
    ran_td: (368..376),
    sor_td: (442..446),
    wiz_td: nil,
    mje_td: (403..455),
    mne_td: (403..455),
    mjs_td: (423..425),
    mns_td: (423..425),
    mnm_td: (320..327),
    defensive_spells: [
      "Cloak of Shadows (712)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Spirit Shield (202)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye",
    "a reinforced dark steel kite shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a cerebralite tentacle",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A grey-splotched pink, the glistening cerebralite is a fleshy mass that somewhat resembles a humanoid brain, though it is oversized and grossly proportioned. Eye-stalks sprout from either hemisphere, supporting a pair of lidless eyes with iridescent irises and ebony pupils. Thick veins span the wrinkled surface of the creature's body, pulsing rhythmically with a writhing mass of barbed tentacles sprouting from its underside. A viscous fluid coats the cerebralite's surface, the substance phlegm-like in consistency."
    ],
    arrival: [
      "A glistening cerebralite just arrived, looking terrified!"
    ],
    flee: [
      "A glistening cerebralite bolts {direction}!"
    ],
    death: [
      "An intangible ripple of pure energy courses through the air as the cerebralite's pupils widen a final time, its eyes clouding over as it dies."
    ],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
    search: [],
    spell_prep: [
      "A glistening cerebralite closes {pronoun} eyes in deep concentration..."
    ],
    attacks: {
      attack: [
        "A glistening cerebralite focuses {pronoun} eye-stalks on you!",
        "A glistening cerebralite lashes at you with {pronoun} barbed tentacle!",
        "A glistening cerebralite lashes at {target} with {pronoun} barbed tentacle!"
      ],
      bolt: [
        "A glistening cerebralite hurls a radiant ball of energy at you!",
        "A glistening cerebralite hurls a stream of fire at {target}!"
      ],
      hurl: [
        "A glistening cerebralite hurls a powerful lightning bolt at {target}!",
        "A glistening cerebralite hurls a chunk of ice at {target}!",
        "A glistening cerebralite hurls a large boulder at {target}!",
        "A glistening cerebralite throws a patchwork wool greatcloak at {target}!"
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
