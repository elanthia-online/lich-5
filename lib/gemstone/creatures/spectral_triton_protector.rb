{
  schema_version: 3,
  name: "spectral triton protector",
  noun: "protector",
  url: "https://gswiki.play.net/spectral_triton_protector",
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
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "non-corporeal undead",
    "Boss"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Atoll",
      uids: [7138101..7138119]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain",
        as: (424..449)
      },
      {
        name: "Claw",
        as: 414
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Shield Charge"
      }
    ],
    special_abilities: [
      {
        name: "Dizzying Swing"
      },
      {
        name: "Mstrike"
      },
      {
        name: "Hurl"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: (270..277),
    ranged: (128..435),
    bolt: (128..435),
    udf: (358..628),
    bar_td: 390,
    cle_td: (392..417),
    emp_td: (404..406),
    pal_td: (339..349),
    ran_td: (353..362),
    sor_td: (419..441),
    wiz_td: nil,
    mje_td: (437..439),
    mne_td: (437..439),
    mjs_td: (385..388),
    mns_td: (385..388),
    mnm_td: (391..399),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bronze-bound driftwood greatshield",
    "a coral-hilted heavy ball and chain"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: [
      "drake greatsword",
      "drake falchion",
      "black ora morning star",
      "drake greataxe"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Coral-spiked pauldrons are draped across a spectral triton protector's shoulders, the leather straps taut across her bare chest, the hide cutting into her tattooed blue-green flesh. Thick rings of ivory encircle her forearms and calves, etched in crude runes caked with blackish mud. Uneven streaks of pigment decorate her sunken cheekbones, the remnants splattered across her trident-inked collarbones."
    ],
    arrival: [
      "A spectral triton protector just arrived.",
      "A spectral triton protector rushes in with powerful strides, {pronoun} slender tail flickering behind {pronoun}!"
    ],
    flee: [
      "A spectral triton protector heads {direction}."
    ],
    death: [
      "The triton protector fades into transparency, {pronoun} remnants rapidly dissolving into the air.",
      "A spectral triton protector goes limp as the last of {pronoun} life is crushed from {pronoun} by {target} unyielding bearhug!",
      "A spectral triton protector goes limp as the last of {pronoun} energy is crushed from {pronoun} by {target} unyielding bearhug!",
      "A spectral triton protector falls to the ground and rolls, trying to smother the flames that surround {pronoun}."
    ],
    decay: [],
    search: [
      "A spectral triton protector glances around, sure that {pronoun} has missed something..."
    ],
    spell_prep: [],
    stun_break: [
      "A spectral triton protector flares briefly with a dull glow, rousing {reflexive} from slumber."
    ],
    ambient: [
      "A spectral triton protector is surrounded by an ominous, chitinous clicking!"
    ],
    attacks: {
      attack: [
        "A spectral triton protector swings {weapon} at you!",
        "Tightening {pronoun} grip on {pronoun} heavy ball and chain, a {pronoun} strikes out at you with all of {pronoun} might!",
        "A spectral triton protector swings a coral-hilted heavy ball and chain at {target}!",
        "A spectral triton protector strikes out at {target} with all of {pronoun} might!",
        "A spectral triton protector swings a beech-hafted gornar crowbill at {target}!",
        "A spectral triton protector swings a drake greatsword at {target}!",
        "A spectral triton protector swings a fel-handled mithril war hammer at {target}!",
        "A spectral triton protector swings a veil iron cudgel at {target}!",
        "A spectral triton protector swings a drake greataxe at {target}!",
        "A spectral triton protector swings a vultite ball and chain at {target}!",
        "A spectral triton protector swings a drakar-beaded whip at {target}!",
        "A spectral triton protector swings a drake falchion at {target}!",
        "A spectral triton protector swings a black ora morning star at {target}!",
        "A spectral triton protector swings an archaic black ora mace at {target}!",
        "A spectral triton protector manages to block with the exact angle needed to deflect the attack right back at you!"
      ],
      claw: [
        "A spectral triton protector claws at you!"
      ],
      hurl: [
        "A spectral triton protector throws {weapon} at you!",
        "A spectral triton protector throws a coral-hilted heavy ball and chain at {target}!",
        "A spectral triton protector throws a cracked kelyn morning star at {target}!",
        "A spectral triton protector throws a fel-handled mithril-spiked cudgel at {target}!",
        "A spectral triton protector throws a drake greatsword at {target}!"
      ],
      shield_charge: [
        "A spectral triton protector charges forward at you with {pronoun} driftwood greatshield and attempts a shield charge!",
        "A spectral triton protector charges forward at {target} with {pronoun} driftwood greatshield and attempts a shield charge!"
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
