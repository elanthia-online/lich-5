{
  schema_version: 3,
  name: "jungle troll",
  noun: "troll",
  url: "https://gswiki.play.net/jungle_troll",
  picture: "",
  level: 26,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 310,
  speed: 7,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Karazja Jungle",
      uids: [5006001..5006009, 5006040..5006040]
    },
    {
      name: "Greymist Woods",
      uids: [3021001..3021016, 3022001..3022034]
    },
    {
      name: "unmapped",
      uids: [5006010..5006039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Falchion",
        as: 209
      },
      {
        name: "Claw (attack)",
        as: 199
      },
      {
        name: "Bamboo-hilted machete",
        as: 209
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Lash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (89..119),
    ranged: (89..116),
    bolt: (89..116),
    udf: 157,
    bar_td: nil,
    cle_td: 97,
    emp_td: 99,
    pal_td: (90..93),
    ran_td: 93,
    sor_td: 99,
    wiz_td: nil,
    mje_td: 98,
    mne_td: 98,
    mjs_td: 99,
    mns_td: 99,
    mnm_td: (78..85),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bamboo-hilted machete"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll knuckle",
    other: [
      "small troll tooth",
      "ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "A thin, tall creature, the jungle troll scampers over the terrain in quick bursts, its long legs and arms seemingly moving in different directions as it shifts course. The jungle troll's dark green, mottled skin displays an oily sheen, and hair is nowhere to be found on its body. The jungle troll's most striking feature, though, is its elongated face. An exaggerated chin extends a foot or more below a thin-lipped mouth, and tall, pointed ears stand up straight atop its head. Its eyes appear stretched, and the silver, slitted pupils could almost be called cat-like if they didn't run horizontally instead of vertically."
    ],
    arrival: [
      "A jungle troll lumbers in at a run!",
      "A jungle troll just arrived!"
    ],
    flee: [
      "A jungle troll runs {direction}."
    ],
    death: [
      "The jungle troll falls to the ground as the stillness of death overtakes {pronoun}.",
      "The jungle troll falls to the floor as the stillness of death overtakes {pronoun}."
    ],
    decay: [
      "A jungle troll decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A jungle troll swings {weapon} at you!"
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
