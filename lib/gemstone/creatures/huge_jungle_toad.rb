{
  schema_version: 3,
  name: "huge jungle toad",
  noun: "toad",
  url: "https://gswiki.play.net/huge_jungle_toad",
  picture: "",
  level: 25,
  family: "Amphibian",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 300,
  speed: 12,
  height: nil,
  size: "",
  areas: [
    {
      name: "Monsoon Jungle",
      uids: [3218017..3218023, 3218045..3218048]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 222
      },
      {
        name: "Charge (attack)",
        as: 232
      },
      {
        name: "Bite",
        as: (199..230)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "poisonous glob of phlegm"
      },
      {
        name: "Glob"
      }
    ],
    special_abilities: [
      {
        name: "Poison spit"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "10N",
    immunities: [],
    melee: (122..157),
    ranged: (131..134),
    bolt: (131..134),
    udf: (311..343),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 83,
    wiz_td: nil,
    mje_td: (86..92),
    mne_td: (86..92),
    mjs_td: nil,
    mns_td: 80,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "green jungle toad hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Covered in dozens of tiny pustules, the jungle toad has a dry skin that is pigmented with varying hues. Ridges around its eyes culminate at its chin, while the thin lips framing its mouth are limned in ebon. Patterns resembling bark decorate its back, and darken closest to the center of its spine. Large, wide, and fat, the jungle toad has a large parotoid gland that lies behind its eyes, which have horizontal pupils set within sickly yellow irises. Fleshy webbing spreads between its toes, though its fingers are oddly free of it."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A huge jungle toad attempts to bite you!"
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
