{
  schema_version: 3,
  name: "triton radical",
  noun: "radical",
  url: "https://gswiki.play.net/triton_radical",
  picture: "",
  level: 100,
  family: "Triton",
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
  max_hp: 300,
  speed: 3,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Ruined Temple",
      uids: [3031036..3031042, 3031056..3031106]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Scaling fork",
        as: (430..520)
      },
      {
        name: "Trident",
        as: 430
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Censure (316)",
        cs: 415
      },
      {
        name: "Divine Strike (1615)",
        cs: 424
      },
      {
        name: "Divine Wrath (335)",
        cs: 403
      },
      {
        name: "Frenzy (216)",
        cs: 409
      },
      {
        name: "Judgment (1630)",
        cs: 409
      },
      {
        name: "Point",
        cs: 421
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Bull Rush"
      },
      {
        name: "Charge"
      },
      {
        name: "Shield Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (291..567),
    ranged: (229..510),
    bolt: (229..510),
    udf: (520..649),
    bar_td: 375,
    cle_td: (402..407),
    emp_td: (369..445),
    pal_td: (335..352),
    ran_td: 355,
    sor_td: (416..420),
    wiz_td: nil,
    mje_td: (414..453),
    mne_td: (414..453),
    mjs_td: (384..392),
    mns_td: (384..392),
    mnm_td: (317..327),
    defensive_spells: [
      "Divine Shield",
      "Fasthr's Reward",
      "Lesser Shroud",
      "Mantle of Faith",
      "Warding Sphere"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a corroded bronze scaling fork",
    "a spike-studded silvery blue round shield",
    "a wide silvery green trident"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an elongated triton spine",
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "tiny golden seed",
      "radiant crimson essence shard"
    ],
    armaments: [
      "drake greataxe"
    ],
    transmogs: nil
  },
  messaging: {
    description: [
      "Glaring angrily and gnashing his sharp yellowed teeth, the triton radical stalks along muttering to himself as if involved in angry debate with a phantasmal antagonist. Pale, red-rimmed eyes sit deep in a heavy-boned skull, which perches upon a long, slender neck. The radical's body pitches forward alarmingly, so only the weight of his tail prevents a return to a four-legged posture. Upon his tapered brow is set a golden crown bearing a large, wave-etched crystal drop."
    ],
    arrival: [
      "A triton radical strides in, a wary look on {pronoun} face.",
      "A triton radical strides in, gliding swiftly through the water with a wary look on {pronoun} face.",
      "A triton radical just arrived.",
      "A triton radical just came through a crumbling arch.",
      "A triton radical staggers in, dragging {reflexive} along with labored breaths."
    ],
    flee: [
      "A triton radical just went through a crumbling arch.",
      "A triton radical just went across a wide stone causeway."
    ],
    death: [
      "The triton radical gurgles once and goes still, a wrathful look on {pronoun} face.",
      "The triton radical collapses to the floor with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton radical collapses to the ground with a splash, gurgling once with a wrathful look on {pronoun} face before expiring.",
      "The triton radical collapses, gurgling once with a wrathful look on {pronoun} face before expiring."
    ],
    decay: [
      "The siren's soft aura fades and her flesh crumbles to reveal the corpse of a hideous scaled creature, which then quickly decays away.",
      "A triton radical's slick skin begins to rapidly desiccate and dissolve away, leaving nothing behind."
    ],
    search: [],
    spell_prep: [
      "A triton radical's eyes glow with silvery grey light, and then everything around you shimmers to match the argentine color.",
      "A triton radical steeples {pronoun} clawed fingers together, murmuring a quick incantation."
    ],
    attacks: {
      attack: [
        "A triton radical thrusts with a corroded bronze scaling fork at you!",
        "A triton radical thrusts with a wide silvery green trident at you!",
        "A triton radical charges into view, {pronoun} determination clear in {pronoun} battle-ready stance!",
        "A triton radical thrusts with a razor-tined pale green trident at you!",
        "The triton radical slams into you, and you are sent careening to the ground!"
      ],
      charge: [
        "A triton radical rushes forward at you with {pronoun} silvery green trident and attempts a charge!",
        "A triton radical rushes forward at you with {pronoun} bronze scaling fork and attempts a charge!"
      ],
      shield_charge: [
        "A triton radical charges forward at you with {pronoun} blue round shield and attempts a shield charge!"
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
