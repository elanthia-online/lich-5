{
  schema_version: 3,
  name: "Ithzir champion",
  noun: "champion",
  url: "https://gswiki.play.net/ithzir_champion",
  picture: "",
  level: 102,
  family: "Ithzir",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: 4,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004080..17004120]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Flamberge",
        as: (446..456)
      },
      {
        name: "Maul",
        as: (440..461)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Arm of the Arkati (1605)"
      }
    ],
    maneuvers: [
      {
        name: "Disarm Weapon"
      },
      {
        name: "Bull Rush"
      },
      {
        name: "True Strike"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Quickstrike"
      },
      {
        name: "Seanette's Shout"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [
      "stun"
    ],
    melee: 304,
    ranged: (268..468),
    bolt: (268..468),
    udf: (476..826),
    bar_td: 406,
    cle_td: (440..445),
    emp_td: (409..440),
    pal_td: (387..390),
    ran_td: (371..381),
    sor_td: 453,
    wiz_td: 466,
    mje_td: (466..521),
    mne_td: (466..521),
    mjs_td: 440,
    mns_td: 440,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Mantle of Faith (1601)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a gornar flail",
    "a jagged steel flamberge",
    "a segmented steel breastplate",
    "a twisted steel talisman",
    "a heavy steel maul"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "crystal weapon",
    armaments: [
      "heavy crystal-capped maul"
    ],
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "An Ithzir champion swings {weapon} at you!",
        "Tightening {pronoun} grip on {pronoun} gornar flail, an Ithzir champion strikes out at you with all of {pronoun} might!",
        "Tightening {pronoun} grip on {pronoun} steel maul, an Ithzir champion strikes out at you with all of {pronoun} might!",
        "An Ithzir champion exhales sharply, exerting mightily.",
        "The Ithzir champion slams into you, and you are sent careening to the ground!",
        "The Ithzir champion cocks {pronoun} head at you."
      ]
    },
    stand: [
      "An Ithzir champion rises to {pronoun} feet, {pronoun} green eyes blazing!"
    ],
    description: [
      "With a competely tattooed forehead and hands, the champion bears an imperious, domineering presence. Muscular and athletic, the Ithzir champion is a full head taller than the average man, and her light-blue skin is completely hairless. Exuding an air of calm and in control, she appears dangerous and fearsome in any situation - and while she seems mostly humanoid, strange proportions and awkward construction make her alien and unknownable. The champion wears a well made royal blue tunic, with the image of a rearing griffin emblazoned in gold thread on the right breast."
    ],
    arrival: [],
    flee: [],
    death: [
      "The Ithzir champion vainly struggles to rise, then goes still.",
      "An Ithzir champion's body shimmers slightly, then fades from view like a dissipating phantom."
    ],
    decay: [],
    search: [
      "An Ithzir champion looks around for a moment and lets loose an echoing shout! The champion's warcry is clear and triumphant.",
      "An Ithzir champion looks around for a moment before opening {pronoun} mouth, but no sound seems to come out!"
    ],
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
