{
  schema_version: 3,
  name: "mistydeep siren",
  noun: "siren",
  url: "https://gswiki.play.net/mistydeep_siren",
  picture: "",
  level: 2,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 43,
  speed: nil,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "The Toadwort",
      uids: [14007001..14007010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: 50
      },
      {
        name: "Unknown",
        as: 30
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 10
      },
      {
        name: "Vibration Chant (1002)",
        cs: 2
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (0..30),
    ranged: 7,
    bolt: (7..28),
    udf: 39,
    bar_td: 6,
    cle_td: 6,
    emp_td: 6,
    pal_td: (3..6),
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: 6,
    mns_td: 6,
    mnm_td: 6,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a curved bracelet dagger",
    "a pale water silk drape",
    "a wavy silvered dirk",
    "some soft gossamer robes"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "Pristine nymph's hair",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The Mistydeep siren's pale eyes are initially glazed like two frosted, opaque panes of glass but they slowly melt to a warm blue as she transfixes her gaze onto her victims. She uses her melodious voice to allure, along with innocent blue eyes, whispering soft promises of pleasure to entice victims into her control. From a distance away, the Mistydeep siren looks like beautiful maiden with softly draping robes walking aimlessly along the shorelines but without the influence of glamor, it becomes obvious this is no helpless maiden. Her bluish corpselike skin and milky eyes is a dead give away of her true nature to any wary adventurer."
    ],
    arrival: [
      "A Mistydeep siren just arrived."
    ],
    flee: [],
    death: [
      "The Mistydeep siren falls to the ground and dies.",
      "The Mistydeep siren screams one last time and dies."
    ],
    decay: [
      "A Mistydeep siren decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A Mistydeep siren swings a curved bracelet dagger at you!",
        "A Mistydeep siren swings a wavy silvered dirk at {target}!",
        "A mistydeep siren swings a curved bracelet dagger at you!",
        "A mistydeep siren swings a wavy silvered dirk at {target}!"
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
