{
  schema_version: 3,
  name: "banded rattlesnake",
  noun: "rattlesnake",
  url: "https://gswiki.play.net/banded_rattlesnake",
  picture: "",
  level: 16,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 150,
  speed: 8,
  height: 1,
  size: "small",
  areas: [
    {
      name: "Emerald Forest",
      uids: [13301170..13301191, 13301201..13301232, 13301301..13301335]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 182
      },
      {
        name: "(quarantine-recovered)",
        as: 163
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Coil Strike"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (130..176),
    ranged: 127,
    bolt: 127,
    udf: 153,
    bar_td: 42,
    cle_td: (48..54),
    emp_td: (48..56),
    pal_td: (42..51),
    ran_td: (48..54),
    sor_td: (45..54),
    wiz_td: nil,
    mje_td: (42..48),
    mne_td: (42..48),
    mjs_td: 66,
    mns_td: 66,
    mnm_td: (45..54),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a bruised left eye",
    "a bruised right eye"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a rattlesnake rattle, a two-tip rattlesnake rattle",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The banded rattlesnake is recognizable by the wide black and red bands that encircle its tubular-shaped body. The beaded, reptilian eyes constantly stare about in an unflickering gaze as it searches for intruders. Very territorial, this snake provides warning to potential aggressors that they have intruded on its domain by sending the rattles on its tail into flickering motion, emitting a constant rattling hum. When coiled in preparation to attack, the rattlesnake's tongue darts in and out of its mouth to assist in gauging its attack. As the tongue flicks in and out, the rattlesnake's main weapon can be seen, the venom-filled fangs that are its bringers of death."
    ],
    arrival: [
      "A banded rattlesnake slithers in, its tongue darting out to taste the air around it.",
      "A banded rattlesnake slithers in.",
      "A banded rattlesnake slowly slithers in.",
      "A banded rattlesnake just arrived."
    ],
    flee: [
      "A banded rattlesnake slithers {direction}.",
      "A banded rattlesnake slowly slithers {direction}."
    ],
    death: [],
    decay: [
      "A banded rattlesnake decays, leaving nothing but bits of rattle and fang in {pronoun} place."
    ],
    search: [],
    spell_prep: [
      "A banded rattlesnake hisses loudly!",
      "A banded rattlesnake hisses softly."
    ],
    attacks: {
      attack: [
        "A banded rattlesnake uncoils suddenly and tries to sink {pronoun} fangs into you!"
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
