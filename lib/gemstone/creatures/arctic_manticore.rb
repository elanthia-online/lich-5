{
  schema_version: 3,
  name: "arctic manticore",
  noun: "manticore",
  url: "https://gswiki.play.net/arctic_manticore",
  picture: "",
  level: 29,
  family: "Chimeric",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 340,
  speed: 6,
  height: 3,
  size: "large",
  areas: [
    {
      name: "Ice Plains",
      uids: [4127005..4127045]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 194
      },
      {
        name: "Claw",
        as: 194
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (150..170),
    ranged: (140..141),
    bolt: (140..141),
    udf: 179,
    bar_td: nil,
    cle_td: 95,
    emp_td: nil,
    pal_td: (84..87),
    ran_td: 87,
    sor_td: 101,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 105,
    mjs_td: (145..155),
    mns_td: (145..155),
    mnm_td: 87,
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
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an arctic manticore mane",
    other: "Glimmering blue essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The first thing that will strike you about the manticore is its noxious smell. Looking much like a snow-white lion, if such a thing could naturally exist, it appears somewhat like an unkempt lion, but after you wipe away the tears brought to your eyes by its vile stench, you will see that its head is more like that of a man, and it has a long segmented tail like that of a scorpion."
    ],
    arrival: [
      "An arctic manticore just arrived.",
      "An arctic manticore charges in."
    ],
    flee: [
      "An arctic manticore heads {direction}."
    ],
    death: [
      "The arctic manticore falls to the ground and dies.",
      "The arctic manticore screams one last time and dies.",
      "The arctic manticore twitches violently, then dies."
    ],
    decay: [
      "An arctic manticore decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      claw: [
        "An arctic manticore claws at you!"
      ],
      bite: [
        "An arctic manticore tries to bite you!"
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
