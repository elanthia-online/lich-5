{
  schema_version: 3,
  name: "corpulent kresh ravager",
  noun: "ravager",
  url: "https://gswiki.play.net/corpulent_kresh_ravager",
  picture: "",
  level: 106,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 750,
  speed: nil,
  height: 18,
  size: "huge",
  areas: [
    {
      name: "The Hive",
      uids: [13041101..13041132, 13041201..13041230]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bladed forelegs",
        as: 532
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Keening Cry"
      },
      {
        name: "Acid Blood"
      },
      {
        name: "Giant Fall"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: nil,
    ranged: (451..622),
    bolt: (451..622),
    udf: (757..1071),
    bar_td: nil,
    cle_td: (418..427),
    emp_td: 463,
    pal_td: (390..393),
    ran_td: (381..384),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 463,
    mne_td: 463,
    mjs_td: nil,
    mns_td: nil,
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
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "a glittering kresh foreclaw",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Hugely bloated, the abdomen of the kresh ravager is fleshy and sickly white-yellow. It jiggles as the ravager skitters around on undersized legs that, while thin and short, appear to possess enough strength to support the ticklike monstrosity's great bulk. By contrast, the ravager's forelegs are powerful and armored in a glittering substance that resembles diamond. Comically undersized mandibles frame its small mouth, which constantly drips an unsavory yellow-green ichor."
    ],
    arrival: [
      "A corpulent kresh ravager springs in, landing in an earth-shaking crouch."
    ],
    flee: [],
    death: [
      "A corpulent kresh ravager's spasms, rolling over.  Its tiny legs kick at the air before going still.",
      "With a thunderous crash, a corpulent kresh ravager falls to the ground, tiny legs kicking at the air before going still."
    ],
    decay: [
      "A corpulent kresh ravager's vast abdomen deflates, oozing fluids as the ravager succumbs to rapid decay."
    ],
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
