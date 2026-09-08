{
  schema_version: 3,
  name: "bighorn sheep",
  noun: "sheep",
  url: "https://gswiki.play.net/bighorn_sheep",
  picture: "",
  level: 18,
  family: "Caprine",
  type: "Quadruped",
  undead: false,
  blood: false,
  bones: true,
  limbs: nil,
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
  max_hp: 165,
  speed: 10,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Emerald Forest",
      uids: [13301170..13301191, 13301201..13301232]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Impale",
        as: (168..183)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11N",
    immunities: [],
    melee: (67..130),
    ranged: (65..72),
    bolt: (65..72),
    udf: 164,
    bar_td: 54,
    cle_td: (51..54),
    emp_td: (54..62),
    pal_td: (48..57),
    ran_td: (54..60),
    sor_td: 54,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
    mjs_td: 81,
    mns_td: 81,
    mnm_td: (51..60),
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
    gems: nil,
    boxes: nil,
    skin: "a bighorn sheepskin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The bighorn sheep's body is compact and muscular with a short, stubby tail. His triangular-shaped head features a narrow pointed muzzle and short, flopppy ears. The fur is almost deerlike in nature and is shaded brown with the occasional whitish rump patches. The sheep's fur is smooth and composed of an outer coat of brittle guard hairs and short, gray, crimped fleece underfur. Atop his head rest two massive brown horns twisted in a full curl. Each looks out of place on the small triangular-shaped head let alone both. Together they form a symmetry that just looks right."
    ],
    arrival: [
      "A bighorn sheep just arrived.",
      "A bighorn sheep charges in!",
      "A bighorn sheep charges in, snorting in pain!"
    ],
    flee: [
      "A bighorn sheep charges {direction}, snorting in pain.",
      "A bighorn sheep lowers {pronoun} head and charges east.",
      "A bighorn sheep lowers {pronoun} head and charges south.",
      "A bighorn sheep lowers {pronoun} head and charges west.",
      "A bighorn sheep lowers {pronoun} head and charges north."
    ],
    death: [
      "A bighorn sheep collapses, {pronoun} head dropping heavily to the ground as {pronoun} goes still.",
      "A bighorn sheep rolls over, {pronoun} head dropping heavily to the ground as {pronoun} goes still."
    ],
    decay: [
      "A bighorn sheep decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A bighorn sheep lowers {pronoun} head and tries to impale you on {pronoun} horns!",
        "A bighorn sheep charges into the open, {pronoun} head lowered and hooves flying.",
        "A bighorn sheep strikes the ground eagerly with one hoof, looking around for a suitable challenger."
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
