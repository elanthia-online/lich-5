{
  schema_version: 3,
  name: "haggard veiki herald",
  noun: "herald",
  url: "https://gswiki.play.net/haggard_veiki_herald",
  picture: "",
  level: 85,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
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
  speed: 12,
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
    warding_spells: [
      {
        name: "Templar's Verdict (1603)",
        cs: 375
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ethereal Wave"
      },
      {
        name: "Ground Slam"
      },
      {
        name: "Shield Bash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (353..507),
    ranged: (350..465),
    bolt: (350..465),
    udf: 485,
    bar_td: nil,
    cle_td: (359..364),
    emp_td: (368..376),
    pal_td: (325..328),
    ran_td: (322..329),
    sor_td: (366..396),
    wiz_td: nil,
    mje_td: 400,
    mne_td: (385..415),
    mjs_td: (359..364),
    mns_td: (364..374),
    mnm_td: 313,
    defensive_spells: [
      "Mantle of Faith (1601)",
      "Divine Shield (1609)",
      "Faith's Clarity (1612)",
      "Soul Ward (319)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crude zorchar khopesh",
    "a round metal aegis emblazoned with a jagged lightning bolt",
    "some hardened hide armor"
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
      "A haggard veiki herald lumbers ponderously in, azure sparks flickering in {pronoun} eyes to illuminate the ominous crevices of {pronoun} face."
    ],
    flee: [
      "A haggard veiki herald hobbles {direction}, clenching a fist to distract {reflexive} from pain."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [
      "A haggard Veiki herald chants in a low, guttural voice."
    ],
    attacks: {
      attack: [
        "Hoisting {pronoun} zorchar khopesh high, a haggard Veiki herald strikes brutally at you!",
        "A haggard veiki herald touches {pronoun} palm to the ground, sending a charged pulse of energy directly toward you!"
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
