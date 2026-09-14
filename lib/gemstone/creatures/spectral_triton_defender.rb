{
  schema_version: 3,
  name: "spectral triton defender",
  noun: "defender",
  url: "https://gswiki.play.net/spectral_triton_defender",
  picture: "",
  level: 98,
  family: "Triton",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031036..3031042, 3031056..3031106]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Lackluster blue steel harpoon",
        as: 444
      },
      {
        name: "Seaweed-wound rusted steel hatchet",
        as: (424..433)
      },
      {
        name: "Curved vaalorn handaxe",
        as: 432
      },
      {
        name: "Tarnished dark silver harpoon",
        as: 433
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Disarm"
      },
      {
        name: "Feint"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (236..446),
    ranged: (206..428),
    bolt: (206..428),
    udf: (501..744),
    bar_td: nil,
    cle_td: (358..367),
    emp_td: 368,
    pal_td: (311..320),
    ran_td: (305..317),
    sor_td: (376..385),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 391,
    mns_td: 391,
    mnm_td: (294..300),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a lackluster blue steel harpoon",
    "a thick canvas sling",
    "a bronze-bound large driftwood shield",
    "a tarnished dark silver harpoon"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "inky necrotic core"
    ],
    armaments: [
      "drake greataxe",
      "drake greatsword",
      "black ora jeddart-axe",
      "beech-handled black ora halberd",
      "corroded black ora awl-pike"
    ],
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A spectral triton defender swings {weapon} at you!",
        "A spectral triton defender thrusts with a lackluster blue steel harpoon at you!",
        "A spectral triton defender thrusts with a tarnished dark silver harpoon at you!",
        "A spectral triton defender thrusts with a razor-tined pale green trident at you!",
        "A spectral triton defender swings {pronoun} {weapon} at your vultite bastard sword!"
      ],
      charge: [
        "A spectral triton defender rushes forward at you with {pronoun} dark silver harpoon and attempts a charge!",
        "A spectral triton defender rushes forward at you with {pronoun} blue steel harpoon and attempts a charge!"
      ],
      hurl: [
        "A spectral triton defender throws {weapon} at you!"
      ]
    },
    stun_break: [
      "A spectral triton defender flares briefly with a dull glow, rousing {reflexive} from slumber and righting {pronoun} posture."
    ],
    description: [
      "The triton defender forges ahead on powerful legs, as if unaware of their lack of substance, while thick and ropey muscles bunch powerfully along her oddly translucent arms. The skin covering her squat ethereal frame is the color of bleached, dirty leather and seems to retain the clammy wetness of living amphibians. Sweeping behind her muscled limbs, a long tail floats after the creature like a recently abandoned child."
    ],
    arrival: [
      "A spectral triton defender just arrived.",
      "A spectral triton defender just came through a crumbling arch.",
      "A spectral triton defender rushes in with powerful strides, {pronoun} slender tail flickering behind {pronoun}!"
    ],
    flee: [
      "A spectral triton defender just went through a crumbling arch.",
      "A spectral triton defender just went down some short descending stairs.",
      "A spectral triton defender just went across a wide stone causeway.",
      "A spectral triton defender hurtles {reflexive} at you with great speed, but flies slightly off center of {pronoun} target and tumbles to the water with a splash!"
    ],
    death: [
      "The triton defender fades into transparency, {pronoun} remnants rapidly dissolving into the air.",
      "The spectral form of the triton defender tenses in agony as {pronoun} begins to dissolve from the bottom up!"
    ],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away."
    ],
    search: [],
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
