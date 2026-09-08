{
  schema_version: 3,
  name: "minotaur warrior",
  noun: "warrior",
  url: "https://gswiki.play.net/minotaur_warrior",
  picture: "",
  level: 76,
  family: "Minotaur",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 300,
  speed: 8,
  height: 8,
  size: "medium",
  areas: [
    {
      name: "The Hidden Plateau",
      uids: [2167050..2167067, 2167070..2167108, 2167111..2167122]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Greataxe",
        as: 368
      },
      {
        name: "Moon axe",
        as: (368..384)
      },
      {
        name: "Lustrous steel battle axe",
        as: 348
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Bull Rush"
      },
      {
        name: "Disarm"
      },
      {
        name: "Charge"
      },
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (187..489),
    ranged: (178..338),
    bolt: (178..338),
    udf: (379..660),
    bar_td: nil,
    cle_td: (274..280),
    emp_td: (260..263),
    pal_td: (219..228),
    ran_td: (228..237),
    sor_td: (273..294),
    wiz_td: nil,
    mje_td: (297..300),
    mne_td: (297..300),
    mjs_td: 299,
    mns_td: 299,
    mnm_td: (222..228),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a blackened steel moon axe",
    "a deep blue heater shield",
    "a lustrous steel battle axe",
    "some banded grey brigandine armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a minotaur horn",
    other: "Tiny golden seed",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The minotaur warrior has the head of a bull while his muscular body is humanoid with thick arms and broad shoulders. Wearing a mish-mash of leather and chain armor, the fierce minotaur stomps about with hoofed feet brandishing its longsword at every possible foe."
    ],
    arrival: [
      "A minotaur warrior releases an enormous bellow as {pronoun} charges in!"
    ],
    flee: [],
    death: [
      "The minotaur warrior twitches one final time before falling still upon the floor, a look of shock frozen upon {pronoun} face."
    ],
    decay: [
      "The thick skin of a minotaur warrior falls in upon itself as his enormous form decays into a fine dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A minotaur warrior swings {weapon} at you!",
        "Tightening {pronoun} grip on {pronoun} steel battle axe, a {pronoun} strikes out at you with all of {pronoun} might!",
        "A minotaur warrior swings {pronoun} {weapon} at your vultite handaxe!",
        "A minotaur warrior swings {pronoun} {weapon} at your smooth glowbark staff!"
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
