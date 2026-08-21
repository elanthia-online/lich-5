{
  schema_version: 3,
  name: "greater ghoul",
  noun: "",
  url: "https://gswiki.play.net/greater_ghoul",
  picture: "",
  level: 3,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 60,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    },
    {
      name: "The Citadel",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    },
    {
      name: "Vornavian Coast",
      rooms: []
    }
  ],
  spawns: [
    { zone: 18, count: 3, uid_ranges: [[18048, 18058], [18060, 18061], [18065, 18068]] },
    { zone: 2102, count: 1, uid_ranges: [[2102008, 2102020]] },
    { zone: 2162, count: 2, uid_ranges: [[2162001, 2162015]] },
    { zone: 4202, count: 1, uid_ranges: [[4202141, 4202156]] },
    { zone: 14008, count: 2, uid_ranges: [[14008025, 14008051]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 63
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
    asg: "1N",
    immunities: [],
    melee: 12,
    ranged: 8,
    bolt: 8,
    udf: 50,
    bar_td: 9,
    cle_td: 9,
    emp_td: 9,
    pal_td: 9,
    ran_td: 9,
    sor_td: 9,
    wiz_td: 9,
    mje_td: 9,
    mne_td: 9,
    mjs_td: 9,
    mns_td: 9,
    mnm_td: 9,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a ghoul scraping",
    other: nil
  },
  messaging: {
    description: [
      "Larger and meaner then its lesser brethren, the greater ghoul shambles along with filth-encrusted claws and ragged bits of decaying flesh hanging from sharp fangs in its decaying jaws. A few filthy bits of rotting cloth still cling to its diseased and festering body as it wanders dimly in search of more flesh."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
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
