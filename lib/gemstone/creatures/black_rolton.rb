{
  schema_version: 3,
  name: "black rolton",
  noun: "rolton",
  url: "https://gswiki.play.net/black_rolton",
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
      name: "Yander's Farm",
      uids: [14005002..14005019]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 23
      },
      {
        name: "Unknown",
        as: 36
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
    melee: (5..28),
    ranged: 5,
    bolt: 5,
    udf: (37..58),
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
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
    skin: "a rolton ear",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "This is obviously a prime example of the beast of legend, the fiend of song and tale. Known near and far as an implacable enemy of early settlers, it was this ferocious sheeplike creature that earned the epithet of Sorcerer-Killer in its sordid past. The black rolton is covered with a dusty, matted, disgusting-looking black pelt that is abysmally smelly. However, it isn't this trait alone that gives her such a terrifying appearance. As the animal bleats at you, it is then you get a view of the 'maw of death', with its long, curved incisors that gnash and gnaw. The critter has some nasty-looking hooves as well."
    ],
    arrival: [
      "A black rolton just came through the barn door.",
      "A black rolton trots in!"
    ],
    flee: [
      "A black rolton trots {direction}.",
      "A black rolton just went through the barn door.",
      "A black rolton bleats as {pronoun} slowly backs away."
    ],
    death: [
      "The black rolton collapses to the ground, emits a final bleat, and dies.",
      "The black rolton lets out a final agonized bleat and dies."
    ],
    decay: [
      "A black rolton decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A black rolton tries to bite you!"
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
