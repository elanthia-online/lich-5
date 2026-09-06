{
  schema_version: 3,
  name: "triton assassin",
  noun: "assassin",
  url: "https://gswiki.play.net/triton_assassin",
  picture: "",
  level: 96,
  family: "Triton",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: true,
  boss_type: "miniboss",
  otherclass: [
    "Living",
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
      uids: [7138001..7138015]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword"
      },
      {
        name: "Main gauche"
      },
      {
        name: "Claw",
        as: 443
      },
      {
        name: "Coral-hilted heavy ball and chain",
        as: 433
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Groin Kick"
      },
      {
        name: "Cutthroat"
      },
      {
        name: "Kick"
      }
    ],
    special_abilities: [
      {
        name: "Ambush"
      },
      {
        name: "Stealth"
      },
      {
        name: "Vanish"
      },
      {
        name: "Hurl"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (228..662),
    ranged: (270..471),
    bolt: (270..471),
    udf: 483,
    bar_td: 375,
    cle_td: (379..397),
    emp_td: (379..389),
    pal_td: (339..342),
    ran_td: (329..339),
    sor_td: (396..426),
    wiz_td: nil,
    mje_td: (432..440),
    mne_td: (413..441),
    mjs_td: 398,
    mns_td: (364..381),
    mnm_td: (379..381),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a twisted soot black runestaff capped with a gold-caged crystal drop of water"
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
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Dressed in grey-on-black, a triton assassin watches the area intently. The assassin bares her sharply serrated teeth, and her thick tail twitches silently with each breath. Inked upon one muscular forearm is a broken ivory trident overlaying a series of spiky runes."
    ],
    arrival: [
      "A triton assassin stalks in silently, {pronoun} cold eyes gleaming with hatred.",
      "A triton assassin slips into hiding."
    ],
    flee: [],
    death: [
      "The triton assassin gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton assassin collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "A triton assassin's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      hurl: [
        "A triton assassin throws a twisted soot black runestaff at you!",
        "A triton assassin throws a severed assassin arm at you!"
      ],
      cutthroat: [
        "A triton assassin springs upon you from behind and attempts to slit your throat!"
      ],
      attack: [
        "A triton assassin swings {weapon} at you!",
        "A triton assassin leaps from hiding to attack!",
        "A triton assassin kick connects! Waves of pain instantly shoot through your body. Your face seizes up instantly!",
        "A triton assassin kick connects! Waves of pain instantly shoot through your body. The pain causes you to cry out!",
        "A triton assassin kick connects! {target} winces in agony!",
        "A triton assassin kicks at {target} groin!",
        "A triton assassin swings a coral-hilted heavy ball and chain at {target}!",
        "A triton assassin kick connects! Waves of pain instantly shoot through your body. Your eyes snap wide open.",
        "A triton assassin springs upon you from behind and aims a blow to your head!",
        "A triton assassin springs from hiding and aims a blow to {target} head!",
        "A triton assassin swings a twisted soot black runestaff at {target}!",
        "A triton assassin's kick connects! {target} eyes snap wide open.",
        "A triton assassin's kick connects! {target} winces in agony!",
        "A triton assassin's kick connects! {target} mouth opens, but all that comes out is a tiny, high-pitched gasp."
      ],
      claw: [
        "A triton assassin claws at you!"
      ],
      groin_kick: [
        "A triton assassin kicks at your groin!"
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
