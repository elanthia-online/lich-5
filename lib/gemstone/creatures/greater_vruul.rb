{
  schema_version: 3,
  name: "greater vruul",
  noun: "",
  url: "https://gswiki.play.net/greater_vruul",
  picture: "",
  level: 75,
  family: "Vruul",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: false,
  max_hp: 1000,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Broken Lands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (213..238)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 295
      },
      {
        name: "Calm (201)",
        cs: 295
      },
      {
        name: "Frenzy (216)",
        cs: 295
      },
      {
        name: "Interference (212)",
        cs: 295
      },
      {
        name: "Silence (210)",
        cs: 295
      },
      {
        name: "Unbalance (110)",
        cs: 295
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
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 281,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 270,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Bravery (211)",
      "Heroism (215)",
      "Lesser Shroud (120)",
      "Spell Shield (219)",
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)"
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
    skin: "a vruul skin",
    other: nil
  },
  messaging: {
    description: [
      "The greater vruul has tough, leathery hide, as black as midnight. Bat-like wings sprout from its back, but they do not look large or strong enough to support its weight in flight. The vruul's claws are long, sharp and appear to be stained with the blood of many victims. Its eyes are eerie, solid green orbs that seem to glow with an inner power."
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
