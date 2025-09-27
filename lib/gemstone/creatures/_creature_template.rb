{
  # ---------- Identity ----------
  schema_version: 3,            # bumped due to structural changes
  name: "",                     # display name
  noun: "",                     # in-game noun (optional; leave "" if same as name)
  url: "",
  picture: "",

  level: nil,                   # Integer
  family: "",                   # e.g., "canine", "gigas"
  type: "",                     # e.g., "biped", "quadruped", "avian", "ooze"
  undead: "",                   # boolean
  boss: false,                  # special encounter flag (optional)
  otherclass: [],               # any extra tags you keep (optional)
  bcs: nil,                     # true/false/nil if unknown

  # ---------- Physical ----------
  max_hp: nil,                  # base / typical max HP
  speed: nil,                   # free-form or numeric if you standardize
  height: nil,                  # Integer (feet) if known
  size: "",                     # "small" | "medium" | "large" | "huge" | ...

  # ---------- Habitat / Locations ----------
  # Multiple areas, each with its own room list
  areas: [
    # { name: "Hinterwilds", rooms: [/* room ids */] }
  ],

  # ---------- Offense / Capabilities ----------
  attack_attributes: {
    physical_attacks: [
      # { name: "bite", as: 527, damage_type: "puncture" }
    ],
    bolt_spells: [
      # { name: "Minor Cold (1709)", cs: 410, damage_type: "cold" }
    ],
    warding_spells: [
      # { name: "Frenzy (216)", cs: (438..450), effect: "anger" }
    ],
    offensive_spells: [
      # { name: "Major Elemental Wave (435)" }
    ],
    maneuvers: [
      # { name: "shield bash" }
    ],
    special_abilities: [
      # light list of capability names (optional)
      # { name: "frenzy" }, { name: "mstrike" }
    ],
    special_notes: []
  },

  # ---------- Defense ----------
  defense_attributes: {
    asg: nil,                   # "10N" or Integer if you standardize
    immunities: [],             # ["crit_kill", "knockdown", ...]
    melee: nil,                 # DS (Integer or Range)
    ranged: nil,                # DS vs ranged
    bolt: nil,                  # DS vs bolt
    udf: nil,                   # UDF (for UAC)
    bar_td: nil, cle_td: nil, emp_td: nil, pal_td: nil, ran_td: nil,
    sor_td: nil, wiz_td: nil, mje_td: nil, mne_td: nil, mjs_td: nil,
    mns_td: nil, mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },

  # ---------- Player-facing Ability Declarations (for Bestiary) ----------
  # Informational only. Runtime applies effects from code via these ids.
  abilities: [
    # {
    #   id: :frenzy,
    #   name: "Frenzy",
    #   type: :buff,                 # :buff | :debuff | :aura | :proc
    #   target: :self,               # :self | :opponent | :area
    #   typical_duration_s: 30,
    #   effects: { as: +100 },       # human-facing summary
    #   dispellable: true,
    #   notes: "Often preceded by scream/eye-glow; reapply refreshes."
    # }
  ],

  # ---------- Crafting / Misc ----------
  alchemy: [],
  abilities_misc: [], # keep if you want to separate non-combat traits

  # ---------- Treasure ----------
  treasure: {
    coins: nil,                  # true/false/nil
    magic_items: nil,            # true/false/nil
    gems: nil,                   # true/false/nil
    boxes: nil,                  # true/false/nil
    # prefer object form so we can carry flags
    # { name: "inky black valravn plume", blunt_required: false }
    skin: nil,
    other: nil # string or [strings]
  },

  # ---------- Messaging ----------
  # All fields are arrays (even singletons) for uniform consumption.
  messaging: {
    # Flavor (not used for parsing unless you choose to)
    description: [],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],

    # Optional informational block for human tips (NOT triggers)
    info: {
      general: [],               # free-form notes someone wrote about the creature
      class_tips: {              # optional per-profession
        cleric: [], paladin: [], ranger: [], bard: [], wizard: [],
        empath: [], rogue: [], warrior: [], sorcerer: []
      },
      miscellany: []             # any extra flavor lines you want to keep
    },

    # Parsing cues. Keys here are the event ids your runtime understands.
    # Values are arrays of message variants/patterns to match.
    triggers: {
      # frenzy: [
      #   "A savage fork-tongued wendigo's eyes blaze a murderous crimson!"
      # ],
      # pack_bolster: [
      #   "Bolstered by nearby members of its pack, a niveous giant warg ..."
      # ],
      # shield_bash: [
      #   "A brawny gigas shield-maiden ... attempts a shield bash!"
      # ]
    }
  }
}
