{
  schema_version: 3,
  name: "bony tenthsworn occultist",
  noun: "occultist",
  url: "https://gswiki.play.net/bony_tenthsworn_occultist",
  picture: "",
  level: 59,
  family: "Humanoid",
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
  otherclass: [],
  bcs: true,
  max_hp: 238,
  speed: 12,
  height: 4,
  size: "small",
  areas: [
    {
      name: "Crawling Shore",
      uids: [4576101..4576126, 4576151..4576160]
    },
    {
      name: "unmapped",
      uids: [4576127..4576150]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: (274..283)
      }
    ],
    offensive_spells: [
      {
        name: "Condemn (309)"
      },
      {
        name: "Grasp of the Grave (709)"
      }
    ],
    maneuvers: [
      {
        name: "Crimson Smoke"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (307..472),
    ranged: (324..363),
    bolt: (324..363),
    udf: (256..305),
    bar_td: nil,
    cle_td: (261..264),
    emp_td: (244..262),
    pal_td: (227..236),
    ran_td: (223..233),
    sor_td: (264..277),
    wiz_td: nil,
    mje_td: (273..290),
    mne_td: (273..290),
    mjs_td: (253..263),
    mns_td: (253..263),
    mnm_td: (199..207),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a crooked bloodwood runestaff carved with sinuous lines",
    "some dark mauve robes threaded with blood red sigils"
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
    description: [
      "Robed and hooded, the Tenthsworn occultist has fervent eyes the color of dried blood and the sort of pallor earned from days spent out of the sun. His dark robes are stitched with serpentine patterns in crimson, a theme repeated in the symbol at his throat, which takes the form of a pair of intertwined asps. The occultist's face is hollow and he looks as if he has not eaten in some time, though perhaps the zeal within him has burned all spare flesh away. \n\nAppraisal:\nThe Tenthsworn occultist is small in size, about four feet high in his current state."
    ],
    arrival: [
      "A bony Tenthsworn occultist stalks in, overwhelming zeal written upon {pronoun} face."
    ],
    flee: [
      "Zeal written upon {pronoun} face, a bony Tenthsworn occultist stalks {direction}.",
      "Biting {pronoun} lip in pain, a bony Tenthsworn occultist stalks {direction}."
    ],
    death: [
      "The Tenthsworn occultist twitches violently, then dies."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A bony tenthsworn occultist directs a finger twined in crimson smoke at you!"
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
