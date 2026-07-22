{
  schema_version: 3,
  name: "nonomino",
  noun: "",
  url: "https://gswiki.play.net/nonomino",
  picture: "",
  level: 23,
  family: "Humanoid",
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
  max_hp: 190,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Anwyn",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain",
        as: 160
      },
      {
        name: "Dagger",
        as: 160
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blind (311)",
        cs: 139
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: 243,
    ranged: nil,
    bolt: 223,
    udf: 244,
    bar_td: 74,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: (85..98),
    mne_td: (85..98),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Prayer of Protection (303)"
    ],
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "A creature of sublime beauty, the nonomino floats just above the ground in a pulsing sphere of unearthly light. As you watch, he abruptly turns his head to stare, as cracks distend across his visage and the glorious mantle peels away to reveal disease and decay. The incarnation constantly molts his epidermis, regenerating it moments later in a hideous parody of the struggle between life and death. Frozen by the hypnotic horror of his appearance, you almost fail to notice the nonomino's fluid movement, and the adept dance of his hands as he summons his theurgical arsenal."
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
