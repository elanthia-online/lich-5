{
  schema_version: 3,
  name: "silver-scaled cold wyrm",
  noun: "",
  url: "https://gswiki.play.net/silver-scaled_cold_wyrm",
  picture: "",
  level: 120,
  family: "Reptilian",
  type: "Avian",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 5000,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Hinterwilds",
      uids: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 826
      },
      {
        name: "Claw",
        as: 826
      },
      {
        name: "Tail swing",
        as: 826
      },
      {
        name: "Dive",
        as: 826
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Sympathy (1120)",
        cs: 520
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (332..543),
    ranged: (205..536),
    bolt: (205..536),
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: 490,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 490,
    mne_td: 490,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Animalistic Rage, Acid Breath, Acid Mist, Combined Acid/Frost Breath, Frost Breath, Energy Immune Scales, Forceful Plummet (when flying), Frost Breath, Immune to Critical Damage, Immune to Death Flares, Immune to Sleep Effects, Immune to Non-magical Attacks, Multi-strike, Preemptive Strike, Restore Self, Tail Sweep (ground), Terrifying Roar",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Resplendent scales of royal blue brighter than cut gemstones form nigh-impregnable armor over the cold wyrm's sinuous form, sheened with iridescent silver that leavens the intensity of their hue. For all her preternatural beauty, there is a cruel cast to the wyrm's visage. Her snout is tapered and full of serrated teeth, and her predatory amber eyes have slitted pupils. A frill of spines frames the wyrm's head, bright with bands of silver that glint threateningly in the ambient light. Two vast wings branch from the wyrm's shoulders, membranous and paler than the rest of her body, immensely sized to hold the wyrm aloft when riding on currents of air."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    stun_break: [
      "A silver-scaled cold wyrm shakes off the magic.",
      "A silver-scaled cold wyrm tenses {pronoun} vast musculatures and breaks free of the bounds that root {pronoun} to the ground."
    ],
    attacks: {
      attack: [
        "A silver-scaled cold wyrm lashes out with a scythe-like talon at {target}!",
        "A silver-scaled cold wyrm charges toward the nearby shadows, revealing you in your hiding place!",
        "A silver-scaled cold wyrm charges toward the nearby shadows, revealing {target}, who was hidden!",
        "A silver-scaled cold wyrm swoops low and extends {pronoun} sinewy neck so {pronoun} can snap at you!",
        "A silver-scaled cold wyrm folds {pronoun} wings against {pronoun} back and plummets down from the skies, aiming {pronoun} bulk at you!"
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
