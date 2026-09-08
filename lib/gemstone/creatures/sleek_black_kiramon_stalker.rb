{
  schema_version: 3,
  name: "sleek black kiramon stalker",
  noun: "stalker",
  url: "https://gswiki.play.net/sleek_black_kiramon_stalker",
  picture: "",
  level: 108,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 327,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "The Hive",
      uids: [13041101..13041132, 13041201..13041230, 13041301..13041329]
    },
    {
      name: "unmapped",
      uids: [13041330..13041330]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw"
      },
      {
        name: "Stinger (attack)",
        as: (591..597)
      },
      {
        name: "Bite",
        as: (565..597)
      },
      {
        name: "Bladed forelegs",
        as: 519
      },
      {
        name: "Razor-sharp foreleg",
        as: (600..607)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Eviscerate"
      },
      {
        name: "Coup de Grace"
      },
      {
        name: "Dirtkick"
      },
      {
        name: "Charge"
      },
      {
        name: "Dust Kick"
      }
    ],
    special_abilities: [
      {
        name: "Weapon Web"
      },
      {
        name: "Stealth"
      },
      {
        name: "On the Hunt"
      },
      {
        name: "Durable Carapace"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: (445..621),
    bolt: (445..621),
    udf: (727..1064),
    bar_td: nil,
    cle_td: (454..463),
    emp_td: 463,
    pal_td: (425..428),
    ran_td: (416..428),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 515,
    mne_td: 515,
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
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "a mottled kiramon poison gland",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glittering, spherical eyes stand out from the matte black of the kiramon stalker's carapace, which is so dark that it seems to drink the surrounding light. The stalker is a creature seemingly tailored for speed and stealth. Roughly shaped like a mantis, it balances on stick-like legs with powerful hindquarters, and it looks ever ready to spring. Wings like gossamer shadows enfold the stalker's thorax like a dusky cloak."
    ],
    arrival: [
      "A sleek black kiramon stalker creeps in on stick-like legs, making nary a sound."
    ],
    flee: [
      "A sleek black kiramon stalker skitters up to your corpse on silent, chitinous legs, prodding you to see if you will move."
    ],
    death: [
      "A sleek black kiramon stalker goes still, and for a moment {pronoun} seems to blend with the surrounding shadows."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A sleek black kiramon stalker shakes off {pronoun} unconscious state."
    ],
    attacks: {
      attack: [
        "A sleek black kiramon stalker skitters mercilessly forward to slash at you with a razor-sharp foreleg!",
        "A sleek black kiramon stalker twists fluidly to spear you with {pronoun} barbed stinger!",
        "Without warning, a sleek black kiramon stalker glides from the shadows and skitters mercilessly forward to slash at you with a razor-sharp foreleg!",
        "Without warning, a sleek black kiramon stalker glides from the shadows and twists fluidly to spear you with {pronoun} barbed stinger!",
        "A sleek black kiramon stalker attempts to kick dust at you, but is unable to kick up a sufficient amount of dust.",
        "A sleek black kiramon stalker manages to kick a large clump of dust at you!",
        "A sleek black kiramon stalker grabs you by the head and twists violently. You hear a loud *CRACK* as your neck bones snap and your body goes limp!",
        "A sleek black kiramon stalker's aim is slightly off, but {pronoun} still manages to inflict a flesh wound upon you!"
      ],
      bite: [
        "A sleek black kiramon stalker aims a preternaturally swift bite at you!",
        "Without warning, a sleek black kiramon stalker glides from the shadows and aims a preternaturally swift bite at you!"
      ],
      cutthroat: [
        "A sleek black kiramon stalker springs upon you from behind and attempts to slit your throat!"
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
