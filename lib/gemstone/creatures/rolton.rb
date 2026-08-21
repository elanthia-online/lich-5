{
  schema_version: 3,
  name: "rolton",
  noun: "",
  url: "https://gswiki.play.net/rolton",
  picture: "",
  level: 1,
  family: "Caprine",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 28,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Icemule Environs",
      rooms: []
    },
    {
      name: "River's Rest Environs",
      rooms: []
    },
    {
      name: "Wehnimer's Environs",
      rooms: []
    }
  ],
  spawns: [
    { zone: 9, count: 1, uid_ranges: [[9008, 9032]] },
    { zone: 2104, count: 1, uid_ranges: [[2104011, 2104017]] },
    { zone: 4128, count: 1, uid_ranges: [[4128001, 4128008]] },
    { zone: 4301, count: 1, uid_ranges: [[4301001, 4301025]] }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: "+36"
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
    asg: "1",
    immunities: [],
    melee: (16..78),
    ranged: "+5",
    bolt: "+5",
    udf: nil,
    bar_td: "+3",
    cle_td: "+3",
    emp_td: "+3",
    pal_td: "+3",
    ran_td: "+3",
    sor_td: "+3",
    wiz_td: "+3",
    mje_td: 3,
    mne_td: 3,
    mjs_td: "+3",
    mns_td: "+3",
    mnm_td: "+3",
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "rolton pelt",
    other: "no"
  },
  messaging: {
    description: [
      "This is obviously a prime example of the beast of legend, the fiend of song and tale. Known near and far as an implacable enemy of early settlers, it was this ferocious sheeplike creature that earned the epithet of Warrior-Killer in its sordid past. The rolton is covered with a dirty, matted, disgusting-looking grey pelt that might once have been white and is still abysmally smelly. However, it isn't this trait alone that gives him such a terrifying appearance. As the animal bleats at you, it is then you get a view of the 'maw of death', with its long, curved incisors that gnash and gnaw. The critter has some nasty-looking hooves as well."
    ],
    arrival: [],
    flee: [],
    death: [],
    decay: [],
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
