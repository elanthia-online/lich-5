{
  schema_version: 3,
  name: "triton warlock",
  noun: "",
  url: "https://gswiki.play.net/triton_warlock",
  picture: "",
  level: 94,
  family: "Triton",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Atoll",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Runestaff",
        as: 427
      }
    ],
    bolt_spells: [
      {
        name: "Balefire (713)",
        as: "404 to 429"
      }
    ],
    warding_spells: [
      {
        name: "Disintegrate (705)",
        cs: "402 to 438"
      },
      {
        name: "Mind Jolt (706)",
        cs: "402 to 438"
      },
      {
        name: "Torment (718)",
        cs: "402 to 438"
      },
      {
        name: "Dark Catalyst (719)",
        cs: "402 to 438"
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
    melee: 530,
    ranged: nil,
    bolt: nil,
    udf: "500 to 615",
    bar_td: 400,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: "410 to 440",
    wiz_td: nil,
    mje_td: nil,
    mne_td: 446,
    mjs_td: nil,
    mns_td: 391,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Lesser Shroud (120)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)"
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
    skin: "curved black claw",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The amphibian visage of a triton warlock gazes out beneath a frayed dark blue robe, her sun-cracked lips curled back into a sneer as she observes the area with slitted, sickly yellow eyes.  Her emaciated form leans backwards, leaving her sinewy arms exposed to the elements as they grip tightly to her staff, her green-fleshed knuckles branded in rough runes.  Her head rotates at the most minute of changes, nostrils flaring as she murmurs indecipherable incantations to herself in preparation of the unknown.</pre>"
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
