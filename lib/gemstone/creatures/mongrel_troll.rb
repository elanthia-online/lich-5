{
  schema_version: 3,
  name: "mongrel troll",
  noun: "troll",
  url: "https://gswiki.play.net/mongrel_troll",
  picture: "",
  level: 16,
  family: "Troll",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 190,
  speed: 8,
  height: 9,
  size: "large",
  areas: [
    {
      name: "Vornavian Coast",
      uids: [4214101..4214115]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Spear",
        as: 167
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
    asg: "11N",
    immunities: [],
    melee: (68..109),
    ranged: (62..116),
    bolt: (62..116),
    udf: (114..133),
    bar_td: 55,
    cle_td: 63,
    emp_td: 63,
    pal_td: (60..63),
    ran_td: 63,
    sor_td: 59,
    wiz_td: nil,
    mje_td: 55,
    mne_td: 55,
    mjs_td: (57..63),
    mns_td: (57..63),
    mnm_td: (48..55),
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a spear",
    "a war mattock",
    "a wooden shield"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a chipped troll tusk",
    other: "Small troll tooth",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mongrel troll is a repulsive combination of troll and some other lesser creature, if there could be a creature considered lower on the scale of life than a troll. Loathesome and hideous, the mongrel troll would tower above you if its bent, crooked spine didn't force it to hunch over. Mottled grey and brown skin so lumpy and loose, that it doesn't so much cover the troll, but sags loosely over from the troll's frame. Tufts of thick black hair sprout over the skin like a series of ill placed shrubs. A hideously toothy grin spreads across the troll's face displaying misshapen fangs crusted with dried blood. No spark of intellect fires in its narrow piggish eyes."
    ],
    arrival: [
      "A mongrel troll just arrived!",
      "A mongrel troll shambles in!",
      "A mongrel troll just arrived, limping in!"
    ],
    flee: [
      "A mongrel troll limps {direction}.",
      "A mongrel troll runs {direction}."
    ],
    death: [
      "The mongrel troll twitches violently, then dies.",
      "The mongrel troll whimpers pitifully one last time and dies."
    ],
    decay: [
      "A mongrel troll decays into compost."
    ],
    search: [
      "A mongrel troll sniffs around looking for something."
    ],
    spell_prep: [
      "A mongrel troll mutters, \"Srlarloror'rt srar 'mrosrdnragh srar 'r'rar s'r'vr'r'rawrd!\"",
      "A mongrel troll mutters to {reflexive}."
    ],
    attacks: {
      attack: [
        "A mongrel troll thrusts with a spear at you!",
        "A mongrel troll swings a war mattock at you!",
        "A mongrel troll throws {pronoun} head back and howls!"
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
