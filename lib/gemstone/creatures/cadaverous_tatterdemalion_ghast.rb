{
  schema_version: 3,
  name: "cadaverous tatterdemalion ghast",
  noun: "ghast",
  url: "https://gswiki.play.net/cadaverous_tatterdemalion_ghast",
  picture: "",
  level: 101,
  family: "Humanoid",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 325,
  speed: 6,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Moonsedge",
      uids: [4577001..4577028, 4577051..4577058, 4577106..4577123, 4577201..4577214, 4577216..4577249]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 484
      },
      {
        name: "Pound (attack)",
        as: 484
      },
      {
        name: "Bite",
        as: (524..555)
      },
      {
        name: "Fist",
        as: (484..519)
      },
      {
        name: "Kick",
        as: 530
      },
      {
        name: "Charge",
        as: 565
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Tackle"
      },
      {
        name: "Swiftkick"
      },
      {
        name: "Pounce"
      }
    ],
    special_abilities: [
      {
        name: "Leap"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: (433..731),
    ranged: (337..562),
    bolt: (337..562),
    udf: (502..888),
    bar_td: nil,
    cle_td: 439,
    emp_td: (419..427),
    pal_td: (390..412),
    ran_td: (372..381),
    sor_td: 453,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
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
  equipment: [
    "some faded sackcloth garments"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
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
      "Clad in the dilapidated remains of homespun clothing, the ghast's form is only passingly humanoid. Death has transformed his features, filming over his eyes and leaving him with only a sloughing remnant of a nose. His hind legs are powerfully muscled, but his hands have atrophied into long talons that are unsettlingly spare of flesh. He is a scabrous and unwholesome beast, and the smear of dried blood and effluvia around his mouth hints at distasteful appetites. \n\nAppraisal:\n\nThe tatterdemalion ghast is medium in size and about five feet high in her current state."
    ],
    arrival: [
      "A cadaverous tatterdemalion ghast leaps in, landing awkwardly due to {pronoun} injuries.",
      "A cadaverous tatterdemalion ghast just came through some vaulting grey stone doors.",
      "A cadaverous tatterdemalion ghast just came through a heavy steel portcullis.",
      "A cadaverous tatterdemalion ghast just came through a wrought black iron gate."
    ],
    flee: [
      "A cadaverous tatterdemalion ghast bounds {direction}, landing with surprising grace.",
      "A cadaverous tatterdemalion ghast bounds {direction}, {pronoun} fraying clothing flapping as {pronoun} lands in a predatory crouch. {target} bares {pronoun} yellowed teeth in a rasping hiss!"
    ],
    death: [
      "A cadaverous tatterdemalion ghast lets out a hoarse cry that devolves into dry, rasping coughs.  Spasms race through {pronoun} form, dead muscles seizing and clenching before at last going still."
    ],
    decay: [
      "Maggots and buzzing flies burst from a cadaverous tatterdemalion ghast's flesh as {pronoun} skin peels and crumbles.  The scavenging insects rapidly consume the remains, leaving little but brittle bones."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A cadaverous tatterdemalion ghast desperately swings {weapon} at you!",
        "A cadaverous tatterdemalion ghast raises {pronoun} fists overhead and flails violently at you!",
        "A cadaverous tatterdemalion ghast exhales the last of a virulent green mist.",
        "A cadaverous tatterdemalion ghast exhales a virulent green mist toward you, but you are unaffected.",
        "A cadaverous tatterdemalion ghast exhales a virulent green mist toward {target}, but {pronoun} is unaffected.",
        "A cadaverous tatterdemalion ghast slashes relentlessly at {target} with long, yellowed nails!",
        "A cadaverous tatterdemalion ghast grabs you by the head and twists violently. You hear a loud *CRACK* as your neck bones snap and your body goes limp!"
      ],
      pestilence: [
        "A cadaverous tatterdemalion ghast exhales a virulent green mist toward you, instantly infecting you. You convulse violently!"
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
