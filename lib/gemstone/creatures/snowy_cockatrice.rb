{
  schema_version: 3,
  name: "snowy cockatrice",
  noun: "",
  url: "https://gswiki.play.net/snowy_cockatrice",
  picture: "",
  level: 6,
  family: "Basilisk",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 69,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Snowflake Vale",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Charge (attack)",
        as: 109
      },
      {
        name: "Claw",
        as: 99
      },
      {
        name: "Pincer (attack)",
        as: 99
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Stare"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: 38,
    ranged: nil,
    bolt: 31,
    udf: (49..63),
    bar_td: 18,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 18,
    wiz_td: nil,
    mje_td: 18,
    mne_td: 18,
    mjs_td: nil,
    mns_td: 18,
    mnm_td: 18,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "snowy cockatrice tailfeather",
    other: nil
  },
  messaging: {
    description: [
      "A smaller relative of the basilisk, the cockatrice has a serpentine body, with feathered head, wings, and legs. Having the cold, freezing gaze of its larger cousin, the cockatrice should not be treated lightly. A sharp beak and raking claws complete this small but deadly package of evil."
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
