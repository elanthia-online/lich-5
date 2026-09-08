{
  schema_version: 3,
  name: "mongrel hobgoblin",
  noun: "hobgoblin",
  url: "https://gswiki.play.net/mongrel_hobgoblin",
  picture: "",
  level: 5,
  family: "Goblin",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
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
  max_hp: 80,
  speed: 15,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Ocoma Vale",
      uids: [4300004..4300025]
    },
    {
      name: "Muddy Village",
      uids: [7128001..7128015, 7128026..7128030]
    },
    {
      name: "unmapped",
      uids: [7128016..7128025]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: 99
      },
      {
        name: "Spiked club",
        as: (79..89)
      },
      {
        name: "Unknown",
        as: 99
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
    asg: "8",
    immunities: [],
    melee: (10..72),
    ranged: 1,
    bolt: 1,
    udf: (52..113),
    bar_td: nil,
    cle_td: 15,
    emp_td: 15,
    pal_td: (12..15),
    ran_td: 15,
    sor_td: 15,
    wiz_td: nil,
    mje_td: 15,
    mne_td: 15,
    mjs_td: 36,
    mns_td: 36,
    mnm_td: 15,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a spiked club",
    "some lynx hide armor"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a mongrel hobgoblin snout",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mongrel hobgoblin is a horribly misshapen beast, with a hideously deformed face. The large, knotted muscles on her arms betray the creature's strength, which is capable of rending a man's limbs right out of their sockets. Mottled skin with a greenish-yellow hue is splotched with randomly scattered patches of reddish-brown fur. The dark beady eyes of the hobgoblin glare menacingly, as if crushing the life from someone would somehow make her life more bearable."
    ],
    arrival: [
      "A mongrel hobgoblin staggers in, howling ferociously!"
    ],
    flee: [
      "A mongrel hobgoblin snarls as she retreats!",
      "A mongrel hobgoblin shuffles {direction}.",
      "A mongrel hobgoblin hobbles slowly {direction}, howling in pain."
    ],
    death: [
      "The mongrel hobgoblin crumples to the ground and dies.",
      "The mongrel hobgoblin lets out a final scream and goes still."
    ],
    decay: [
      "A mongrel hobgoblin decays into a pile of compost."
    ],
    search: [
      "A mongrel hobgoblin sniffs at the air and glances about with a hungry gleam in {pronoun} eyes."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A mongrel hobgoblin swings {weapon} at you!",
        "A mongrel hobgoblin swings a spiked club at {target}!",
        "A mongrel hobgoblin growls at you!"
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
