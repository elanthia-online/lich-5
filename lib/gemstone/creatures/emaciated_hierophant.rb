{
  schema_version: 3,
  name: "emaciated hierophant",
  noun: "hierophant",
  url: "https://gswiki.play.net/emaciated_hierophant",
  picture: "",
  level: 66,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Temple Wyneb",
      uids: [13300001..13300076, 13300080..13300080]
    },
    {
      name: "unmapped",
      uids: [13300077..13300079]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Espadon",
        as: 331
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Unbalance",
        cs: 279
      }
    ],
    offensive_spells: [
      {
        name: "Sounds"
      },
      {
        name: "Tangle Weed"
      },
      {
        name: "Spike Thorn"
      },
      {
        name: "Spirit Strike"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (325..443),
    ranged: 293,
    bolt: 293,
    udf: (313..484),
    bar_td: (234..244),
    cle_td: 276,
    emp_td: (249..272),
    pal_td: (225..234),
    ran_td: 225,
    sor_td: (274..280),
    wiz_td: nil,
    mje_td: nil,
    mne_td: 288,
    mjs_td: (262..272),
    mns_td: (262..272),
    mnm_td: 250,
    defensive_spells: [
      "Spirit Defense",
      "Spirit Warding II",
      "Fasthr's Reward",
      "Lesser Shroud",
      "Natural Colors",
      "Resist Elements",
      "Mobility"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a dented iron pavis",
    "a scorched rune-etched espadon"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "Glowing violet essence dust",
      "glowing violet essence shard",
      "tiny golden seed",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The emaciated hierophant stands short for a human, and might pass for one except for the storm grey eyes that swirl with unearthly energy. Long robes that appear to float in the air gap to reveal an ornate tunic and breeches with polished green leather boots to the knee. A long golden chain hangs about his neck, a small glowing red crystal suspended as a pendant there. Intricate tattoos cover his flesh, drawing ornate and unrecognizable patterns that glow a dull red and seem to pulse along as if it were blood."
    ],
    arrival: [
      "An emaciated hierophant just arrived.",
      "An emaciated hierophant strides into the area!",
      "An emaciated hierophant charges in, sweat beading on {pronoun} forehead!"
    ],
    flee: [
      "An emaciated hierophant heads {direction}.",
      "An emaciated hierophant limps {direction}."
    ],
    death: [
      "An emaciated hierophant dies and collapses to the floor.",
      "With an ear-piercing cry of agony, the emaciated hierophant dies.",
      "An emaciated hierophant thrashes violently and then dies.",
      "An emaciated hierophant dies, falling down like a rag doll.",
      "An emaciated hierophant staggers, then falls to the floor and dies.",
      "An emaciated hierophant spasms one last time and then dies.",
      "An emaciated hierophant thrashes one last time and goes still.",
      "An emaciated hierophant moans in agony and then goes still.",
      "An emaciated hierophant spasms in death and then goes still."
    ],
    decay: [
      "An emaciated hierophant crumbles to dust and blows away on the wind.",
      "An emaciated hierophant suddenly dissolves into a puddle of viscous ooze.",
      "An emaciated hierophant rapidly decays, flesh and bone crumbling to dust."
    ],
    search: [],
    spell_prep: [
      "An emaciated hierophant gestures and murmurs a quiet prayer.",
      "An emaciated hierophant mumbles a silent prayer!",
      "An emaciated hierophant gestures, cracked lips moving in silent prayer as {pronoun} focuses, shaking the stun."
    ],
    attacks: {
      attack: [
        "An emaciated hierophant fans {pronoun} fingers wide and gestures at you!"
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
