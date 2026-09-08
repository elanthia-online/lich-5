{
  schema_version: 3,
  name: "titan tempest tyrant",
  noun: "tyrant",
  url: "https://gswiki.play.net/titan_tempest_tyrant",
  picture: "",
  level: 83,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
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
  max_hp: 400,
  speed: 8,
  height: 13,
  size: "huge",
  areas: [
    {
      name: "Stormpeak",
      uids: [13150401..13150425]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tempest Strike(?)"
      },
      {
        name: "Feint"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Ethereal Wave"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (277..465),
    ranged: (252..387),
    bolt: (252..387),
    udf: (481..689),
    bar_td: nil,
    cle_td: (292..301),
    emp_td: (292..301),
    pal_td: (254..263),
    ran_td: (251..260),
    sor_td: (298..328),
    wiz_td: nil,
    mje_td: 332,
    mne_td: (317..347),
    mjs_td: 307,
    mns_td: (277..307),
    mnm_td: (252..261),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Barrier (102)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Blink (1215)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude feras morning star",
    "a crude zorchar khopesh",
    "a jagged feras spikestar",
    "some ornate brass scalemail"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [],
    arrival: [
      "A gust of wind and a flash of lightning herald the arrival of a stooped titan stormcaller as {pronoun} lumbers in.",
      "A titan tempest tyrant charges in, electricity crackling down {pronoun} forearms!",
      "A titan tempest tyrant thunders in, rage roiling in {pronoun} glowing eyes.",
      "A titan tempest tyrant thunders in, pain and rage warring in {pronoun} glowing eyes."
    ],
    flee: [],
    death: [
      "A titan tempest tyrant stretches a hand skyward, fumbling for something unseen as {pronoun} surrenders to death.",
      "An odor of burnt ozone fills the air as a titan tempest tyrant's body collapses in upon itself, drying into fine-grained dust that fills the air with grit.",
      "A ragged gasp fills a stooped titan stormcaller's lungs with a last breath that wooshes out as {pronoun} dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A titan tempest tyrant's feras morning star crackles with corruscating lightning as {pronoun} swings it at you!",
        "Tightening {pronoun} grip on {pronoun} feras morning star, a {pronoun} strikes out at you with all of {pronoun} might!",
        "A titan tempest tyrant's feras spikestar crackles with corruscating lightning as {pronoun} swings it at you!"
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
