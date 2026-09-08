{
  schema_version: 3,
  name: "ethereal triton sentry",
  noun: "sentry",
  url: "https://gswiki.play.net/ethereal_triton_sentry",
  picture: "",
  level: 103,
  family: "Triton",
  type: "Biped",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: true,
  max_hp: 238,
  speed: nil,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031081..3031106]
    }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Dark Catalyst (719)",
        cs: (451..457)
      },
      {
        name: "Mana Disruption (702)",
        cs: (451..457)
      },
      {
        name: "Disintegrate (705)",
        cs: (451..457)
      },
      {
        name: "Mind Jolt (706)",
        cs: (451..457)
      }
    ],
    offensive_spells: [
      {
        name: "Implosion (720)"
      },
      {
        name: "Major Elemental Wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "Claw Curse"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: nil,
    ranged: (364..483),
    bolt: (364..483),
    udf: (382..648),
    bar_td: nil,
    cle_td: (440..450),
    emp_td: (432..442),
    pal_td: (379..389),
    ran_td: (385..392),
    sor_td: nil,
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
    "a twisted soot black runestaff capped with a gold-caged crystal drop of water"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "inky necrotic core",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "An ethereal triton sentry points an ethereal, clawed finger toward you!",
        "An ethereal triton sentry swings a twisted soot black runestaff at you!"
      ]
    },
    stun_break: [
      "An ethereal triton sentry flares briefly with a dull glow, rousing {reflexive} from slumber.",
      "An ethereal triton sentry flares briefly with a dull glow, rousing {reflexive} from slumber and righting {pronoun} posture."
    ],
    description: [
      "The triton sentry holds himself erect, as he skims along the ground on long-nailed translucent webbed feet. Obsessively alert, the creature sniffs constantly and halts to listen every few moments. Despite empty eye sockets, constantly weeping viscous green mucus, he peers into the shadows for infiltrators, his head constantly turning with rapid, jerky motions. Threadbare green-belted robes cover his insubstantial frame."
    ],
    arrival: [
      "An ethereal triton sentry just arrived."
    ],
    flee: [],
    death: [
      "The triton sentry fades into transparency, {pronoun} remnants rapidly dissolving into the air."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "An ethereal triton sentry chants in an incomprehensible language, causing streams of dim grey energy to lash about {pronoun} hands."
    ],
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
