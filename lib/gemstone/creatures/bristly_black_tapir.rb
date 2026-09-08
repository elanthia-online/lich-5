{
  schema_version: 3,
  name: "bristly black tapir",
  noun: "tapir",
  url: "https://gswiki.play.net/bristly_black_tapir",
  picture: "",
  level: 29,
  family: "Suine",
  type: "Quadruped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 253,
  speed: 10,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cloud Forest",
      uids: [3219001..3219038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (184..232)
      },
      {
        name: "Charge (attack)",
        as: (194..242)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Charge"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "10N",
    immunities: [],
    melee: (141..266),
    ranged: (132..158),
    bolt: (132..158),
    udf: 247,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (87..93),
    sor_td: 104,
    wiz_td: nil,
    mje_td: (118..121),
    mne_td: (118..121),
    mjs_td: nil,
    mns_td: 87,
    mnm_td: nil,
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a bristly tapir snout",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Tall and broad of shoulder, the tapir is an enormous beast similar to a boar. A short, thick coat of ebon fur spreads across her tightly muscled body, though the pelt fades to pale brown under the tapir's neck and stomach. Tubular nasal cavities stand out from her snout, while a healthy row of chisel-shaped teeth line her narrow mouth. Twin oval ears, each tipped with white, crown the tapir's head. They are spaced a full hand's span apart over her dark brown eyes. A short, stubby tail lays against her protruding rump, and the beast is supported by thick legs that end in splayed hooves."
    ],
    arrival: [
      "A bristly black tapir charges in, raising {pronoun} proboscis to let out a high-pitched squeal!",
      "A bristly black tapir charges in!"
    ],
    flee: [
      "A bristly black tapir charges {direction}."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {},
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
