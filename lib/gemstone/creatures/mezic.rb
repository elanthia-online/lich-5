{
  schema_version: 3,
  name: "mezic",
  noun: "",
  url: "https://gswiki.play.net/mezic",
  picture: "",
  level: 33,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Magical"
  ],
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Foggy Valley",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ball and chain"
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 236
      },
      {
        name: "Minor Fire (906)",
        as: 220
      },
      {
        name: "Minor Shock (901)",
        as: 236
      }
    ],
    warding_spells: [
      {
        name: "Cold Snap (512)",
        cs: 180
      }
    ],
    offensive_spells: [
      {
        name: "Call Wind (912)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: 240,
    ranged: nil,
    bolt: nil,
    udf: nil,
    bar_td: 110,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 113,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 130,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Elemental Defense III (414)",
      "Elemental Focus (513)",
      "Mass Blur (911)",
      "Thurfel's Ward (503)"
    ],
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
    skin: nil,
    other: "Glimmering blue essence shard"
  },
  messaging: {
    description: [
      "Hunched shoulders and a stooping posture, the mezic is humanoid in appearance, her clothes ill-fitting and made of simple cloth. Dark, beady eyes stare at you from beneath a mass of tangled grey hair as the mezic shuffles her hunched form back and forth. Its long, gnarled fingers contort in magical configurations as it glances maliciously about the area."
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
