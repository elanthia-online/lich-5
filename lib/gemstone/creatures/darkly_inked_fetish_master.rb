{
  schema_version: 3,
  name: "darkly inked fetish master",
  noun: "master",
  url: "https://gswiki.play.net/darkly_inked_fetish_master",
  picture: "",
  level: 104,
  family: "Humanoid",
  type: "biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Extraplanar",
    "Living"
  ],
  bcs: true,
  max_hp: 238,
  speed: 7,
  height: 4,
  size: "small",
  areas: [
    {
      name: "The Rift",
      uids: [4571001..4571030]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Silence (210)"
      },
      {
        name: "Unbalance (110)",
        cs: 455
      }
    ],
    offensive_spells: [
      {
        name: "Sounds (607)"
      },
      {
        name: "Spike Thorn (616)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (439..613),
    bolt: 388,
    udf: (505..783),
    bar_td: 411,
    cle_td: (452..461),
    emp_td: (443..449),
    pal_td: (407..410),
    ran_td: (405..407),
    sor_td: nil,
    wiz_td: 495,
    mje_td: (507..510),
    mne_td: (449..510),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [
    {
      id: :sounds,
      name: "Sounds (607)",
      type: :debuff,
      target: :opponent,
      typical_duration_s: 22,
      effects: { spell_failure_chance: true },
      dispellable: nil,
      notes: "No warding roll seen."
    },
    {
      id: :silence,
      name: "Silence (210)",
      type: :debuff,
      target: :opponent,
      typical_duration_s: 21,
      effects: { silenced: true },
      dispellable: nil,
      notes: "Warding, CS 440-458."
    },
    {
      id: :sleep,
      name: "Sleep (501)",
      type: :debuff,
      target: :opponent,
      typical_duration_s: 19,
      effects: { asleep: true },
      dispellable: nil,
      notes: "Warding, CS 429."
    }
  ],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a stout rotting wood staff",
    "some loosely fitted torn ochre robes"
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
      "A darkly inked fetish master can be found in the Scatter in the Rift. This creature is a child-like voodoo witch doctor, drawing upon elaborate inked designs on its skin for its dark powers. The masters cast mostly Sorcerer spells and can summon a cluster of wooden dolls on their current target, who would lay down a barrage of attacks.\n\nDark-ringed eyes stare out of a face that is gaunt and ashen as a darkly inked fetish master looks on. Beginning at its hairline, a labyrinthine pattern of tattoos in ebon ink crawl across the fetish master's skin, spanning brow and cheeks alike. The designs sheath every inch of exposed skin not shrouded beneath its tattered robes. In a grotesque display, the fetish master's lips have been peeled back from its gums, secured in place by a set of discolored hooks. Perhaps not the intention, but the effect creates a perpetual, toothy grin that seems to hold no amusement, but ample amounts of malice."
    ],
    arrival: [
      "A darkly inked fetish master arrives, the skulls on its belt clacking with a hollow resonance.",
      "A darkly inked fetish master wanders in, set with a distant gaze focused on seemingly nothing at all."
    ],
    flee: [],
    death: [
      "As a darkly inked fetish master slumps to the ground, the darkly lined tattoos traversing its skin lose the luminescence that had seemed to radiate from them."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A darkly inked fetish master raises {pronoun} hands while emitting a dissonant sing-song rhythm, causing the tattoos along {pronoun} forearms and hands to flare to life with a dark light.",
      "A darkly inked fetish master mumbles a few words, {pronoun} voice small and quiet as tendrils of purple crawl along the tattoos lining {pronoun} forearms!"
    ],
    stun_break: [
      "A darkly inked fetish master wheezes raspily, unable to regain {pronoun} composure."
    ],
    attacks: {
      attack: [
        "A darkly inked fetish master swings a stout rotting wood staff at you!",
        "A darkly inked fetish master claps {pronoun} palms together, momentarily uniting {pronoun} glowing tattoos before forcefully thrusting {pronoun} hands forward toward you!"
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
    triggers: {
      sleep: [
        "A darkly inked fetish master claps {pronoun} palms together, momentarily uniting {pronoun} glowing tattoos before forcefully thrusting {pronoun} hands forward toward you!",
        "Your mind goes completely blank."
      ],
      silence: [
        "A darkly inked fetish master claps {pronoun} palms together, momentarily uniting {pronoun} glowing tattoos before forcefully thrusting {pronoun} hands forward toward you!",
        "A fresh smell haunts the chill air here, and underfoot, the ground is green-tinged and full of seeds.  What looks to be strips of cucumber are laid out side by side, studded here and there by a sliced ring of black olive.  Opaque granules the size of small apples appear to have been sprinkled over the cucumbers, and looking up finds a substance that is very pale and porous, much like bread.  Though there is no crust on the odd ceiling above, it has been smeared with a white and green-flecked substance.  You also see a murky soul siphon, a darkly inked fetish master and a darkly inked fetish master.",
        "A pall of silence settles over you."
      ],
      sounds: [
        "A darkly inked fetish master claps {pronoun} palms together, momentarily uniting {pronoun} glowing tattoos before forcefully thrusting {pronoun} hands forward toward you!",
        "You hear strange noises come from behind and to either side of you."
      ]
    }
  }
}
