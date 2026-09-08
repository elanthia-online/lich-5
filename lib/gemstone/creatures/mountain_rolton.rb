{
  schema_version: 3,
  name: "mountain rolton",
  noun: "rolton",
  url: "https://gswiki.play.net/mountain_rolton",
  picture: "",
  level: 1,
  family: "Caprine",
  type: "Quadruped",
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
  max_hp: 28,
  speed: 15,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Luinne Bheinn",
      uids: [4251018..4251027]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (28..36)
      },
      {
        name: "Unknown",
        as: 28
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
    asg: "1N",
    immunities: [],
    melee: (7..28),
    ranged: (-5..5),
    bolt: 5,
    udf: (26..47),
    bar_td: nil,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: nil,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    skin: "rolton eye",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This is obviously a prime example of the beast of legend, the fiend of song and tale. Known near and far as an implacable enemy of early settlers, it was this ferocious sheeplike creature that earned the epithet of Warrior-Killer in its sordid past. The rolton is covered with a dirty, matted, disgusting-looking grey pelt that might once have been white and is still abysmally smelly. However, it isn't this trait alone that gives him such a terrifying appearance. As the animal bleats at you, it is then you get a view of the 'maw of death', with its long, curved incisors that gnash and gnaw. The critter has some nasty-looking hooves as well."
    ],
    arrival: [
      "A mountain rolton just arrived.",
      "A mountain rolton ambles in."
    ],
    flee: [
      "A mountain rolton trots {direction}.",
      "A mountain rolton bleats as {pronoun} slowly backs away."
    ],
    death: [
      "The mountain rolton collapses to the ground, emits a final bleat, and dies.",
      "The mountain rolton lets out a final agonized bleat and dies.",
      "The mountain rolton twitches violently, then dies.",
      "The mountain rolton collapses to the ground, emits a final silent bleat, and dies."
    ],
    decay: [
      "A mountain rolton decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A mountain rolton tries to bite you!"
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
