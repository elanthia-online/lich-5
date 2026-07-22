{
  schema_version: 3,
  name: "banded rattlesnake",
  noun: "",
  url: "https://gswiki.play.net/banded_rattlesnake",
  picture: "",
  level: 16,
  family: "Reptilian",
  type: "Ophidian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 150,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Masked Hills",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 182
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
    melee: (157..176),
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 42,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 48,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 42,
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
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a rattlesnake rattle, a two-tip rattlesnake rattle",
    other: nil
  },
  messaging: {
    description: [
      "The banded rattlesnake is recognizable by the wide black and red bands that encircle its tubular-shaped body. The beaded, reptilian eyes constantly stare about in an unflickering gaze as it searches for intruders. Very territorial, this snake provides warning to potential aggressors that they have intruded on its domain by sending the rattles on its tail into flickering motion, emitting a constant rattling hum. When coiled in preparation to attack, the rattlesnake's tongue darts in and out of its mouth to assist in gauging its attack. As the tongue flicks in and out, the rattlesnake's main weapon can be seen, the venom-filled fangs that are its bringers of death."
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
