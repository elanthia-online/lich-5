{
  schema_version: 3,
  name: "branded goliath diviner",
  noun: "diviner",
  url: "https://gswiki.play.net/branded_goliath_diviner",
  picture: "",
  level: 115,
  family: "Goliath",
  type: "",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true, # Wither (1115) worked 26x in session logs
  sympathy: nil,
  muggable: nil,
  sleepable: true, # Sleep (501) worked 9x in session logs
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Empyrean Onslaughts",
      uids: []
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Mana Burst (1414)",
        cs: (369..396)
      },
      {
        name: "Thought Lash (1210)",
        cs: (384..390)
      }
    ],
    offensive_spells: [
      {
        name: "Mystic Impedance (1708)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Runestone"
      },
      {
        name: "Fate Shadows"
      },
      {
        name: "Doom Sign"
      },
      {
        name: "Force Burst"
      },
      {
        name: "Time Spike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
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
  abilities: [
    {
      id: :mystic_impedance,
      name: "Mystic Impedance (1708)",
      type: :debuff,
      target: :opponent,
      typical_duration_s: 30,
      effects: { blocks_spells_at_or_above: 15 },
      dispellable: nil,
      notes: "Follows the finger-flick spell_prep line; no warding roll (autosuccess). Golden runes onset. Blocks PREPARE of spells at or above the threshold; lower spells still work. Threshold is an upper bound: 515 observed blocked, exact floor unconfirmed."
    },
    {
      id: :doom_sign,
      name: "Doom Sign",
      type: :debuff,
      target: :opponent,
      typical_duration_s: nil,
      effects: nil,
      dispellable: nil,
      notes: "MDR maneuver. On success a Debuffs bar named Doom Sign appears with a 2-4s countdown, and a death was seen at its expiry. Mechanism at expiry not confirmed."
    }
  ],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A branded goliath diviner's is tall and with a rangy build, clad in flowing robes of white and silver that shimmer with faint hints of other colors. His head is shaven bald, or perhaps is naturally that way, and the skin there is decorated with an intricate knotwork tattoo in shades of electric blue and intense violet. Elsewhere on his body, the design recurs in livid-looking brands marring his flesh."
    ],
    arrival: [
      "A branded goliath diviner glides in with an otherworldly grace, surveying the surroundings with a knowing look."
    ],
    flee: [],
    death: [
      "A branded goliath diviner's dreamy gaze goes lifeless.",
      "A branded goliath diviner's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A branded goliath diviner completes {pronoun} silent incantation and, without so much as a glance, flicks a finger at you!"
    ],
    stun_break: [
      "A branded goliath diviner looks around as if waking up from a dream."
    ],
    attacks: {
      attack: [
        "A branded goliath diviner raises a clenched fist, opening {pronoun} to reveal a small rune-etched stone pulsing with inner light. The stone hovers momentarily over {pronoun} palm before rising into the air, seeming to expand in every direction until {pronoun} is a pale hovering runestone wreathed in glowing colors!",
        "A branded goliath diviner throws {pronoun} arms skyward!",
        "A branded goliath diviner raises a clenched fist, opening {pronoun} to reveal a small rune-etched stone pulsing with inner light. The stone hovers momentarily over his palm before rising into the air, seeming to expand in every direction until it is a pale hovering runestone wreathed in glowing colors!",
        "A branded goliath diviner conjures a swirling orb of hungry flame and hurls {pronoun} toward you!",
        "A branded goliath diviner extends {pronoun} hands, palms outward, and a shimmering wave of force thunders toward you!"
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
      mystic_impedance: [
        "A dizzying array of golden runes surround and suffuse you before being absorbed into your body."
      ],
      mana_burst: [
        "The very fabric of reality surrounding you fluctuates wildly!",
        "The very fabric of reality surrounding {target} fluctuates wildly!"
      ],
      thought_lash: [
        "A crackling whip of energy lashes out at you!"
      ],
      doom_sign: [
        "The ominous sigil flares brightly as it streaks toward you, melding with your flesh.  A shiver of anticipation goes up your spine and your heart begins to quiver."
      ]
    }
  }
}
