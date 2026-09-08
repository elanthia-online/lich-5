{
  schema_version: 3,
  name: "smouldering skeletal dreadsteed",
  noun: "dreadsteed",
  url: "https://gswiki.play.net/smouldering_skeletal_dreadsteed",
  picture: "",
  level: 103,
  family: "Equine",
  type: "Quadruped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 500,
  speed: 8,
  height: 5,
  size: "large",
  areas: [
    {
      name: "Moonsedge",
      uids: [4577001..4577028, 4577051..4577058, 4577106..4577123, 4577201..4577214]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 520
      },
      {
        name: "Charge (attack)",
        as: 530
      },
      {
        name: "Stomp (attack)",
        as: 520
      },
      {
        name: "Bite",
        as: (567..575)
      },
      {
        name: "Charge",
        as: (530..576)
      },
      {
        name: "Kick",
        as: (555..561)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Flaming Aura (1706)"
      }
    ],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Headbutt"
      },
      {
        name: "Charge"
      },
      {
        name: "Lash"
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
    asg: "15N",
    immunities: [],
    melee: (392..735),
    ranged: (299..544),
    bolt: (299..544),
    udf: (562..940),
    bar_td: 395,
    cle_td: (397..406),
    emp_td: 400,
    pal_td: (362..393),
    ran_td: 503,
    sor_td: (408..437),
    wiz_td: nil,
    mje_td: 351,
    mne_td: (425..447),
    mjs_td: nil,
    mns_td: 388,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "some black steel chain barding"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a flame-scarred dreadsteed skull",
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Clad in fatigued barding, the skeletal dreadsteed is an ossified vestige of a powerful steed. Bits of dried flesh cling to the bones, but its ribcage is an open ruin that holds a twisting, nebulous orb of phantasmal blue flame. More cerulean fire sprouts from its skull, neck, and hinquarters as an unearthly mane and tail. Its bony hooves are shod in old steel.\n\nAppraisal:\n\nThe skeletal dreadsteed is large in size and about five feet high in its current state."
    ],
    arrival: [
      "A smouldering skeletal dreadsteed just came through a wrought black iron gate.",
      "A smouldering skeletal dreadsteed just came through a heavy steel portcullis.",
      "A smouldering skeletal dreadsteed just came through some vaulting grey stone doors.",
      "A smouldering skeletal dreadsteed charges in, carrying {target}.",
      "A smouldering skeletal dreadsteed charges in, limping visibly.",
      "A smouldering skeletal dreadsteed canters in, ridden by an infernal death knight.",
      "A smouldering skeletal dreadsteed limps in, {pronoun} ossified legs wobbling with the effort of carrying an infernal death knight.",
      "A smouldering skeletal dreadsteed canters in, azure sparks flying from {pronoun} fiery mane."
    ],
    flee: [
      "A smouldering skeletal dreadsteed limps visibly as {pronoun} charges north.",
      "A smouldering skeletal dreadsteed limps visibly as {pronoun} charges east.",
      "A smouldering skeletal dreadsteed limps visibly as {pronoun} charges west."
    ],
    death: [],
    decay: [],
    search: [
      "A smouldering skeletal dreadsteed looks around balefully."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A smouldering skeletal dreadsteed gallops into a deadly charge at you!",
        "A smouldering skeletal dreadsteed rears up onto {pronoun} ossified hind legs and kicks at you with steel-shod hooves!",
        "Urged on by the knight riding smouldering skeletal dreadsteed, a smouldering skeletal dreadsteed gallops into a deadly charge at you!",
        "A smouldering skeletal dreadsteed slams {pronoun} head into you!",
        "A smouldering skeletal dreadsteed throws back {pronoun} head and unleashes a terrible death whinny, {pronoun} mane blowing in an otherworldly breeze.",
        "A smouldering skeletal dreadsteed kicks languidly in {pronoun} sleep, {pronoun} iron-shod hooves flailing at the air ineffectually.",
        "A smouldering skeletal dreadsteed kicks at the air, rearing back to unleash a discordant whinny that echoes as if from a great distance.",
        "A smouldering skeletal dreadsteed slams {pronoun} head into {target}!",
        "A smouldering skeletal dreadsteed charges towards {target} and attempts to headbutt {pronoun}!",
        "The smouldering skeletal dreadsteed barrels into {target} at full speed!"
      ],
      bite: [
        "A smouldering skeletal dreadsteed opens {pronoun} skeletal maw and tries to bite you!"
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
