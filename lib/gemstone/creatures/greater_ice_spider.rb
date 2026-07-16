{
  schema_version: 3,
  name: "greater ice spider",
  noun: "",
  url: "https://gswiki.play.net/greater_ice_spider",
  picture: "",
  level: 3,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 44,
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
        name: "Pincer (attack)",
        as: 48
      },
      {
        name: "Stinger (attack)",
        as: 71
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Webbed"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (29..81),
    ranged: nil,
    bolt: 35,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 9,
    wiz_td: nil,
    mje_td: 9,
    mne_td: 9,
    mjs_td: nil,
    mns_td: 9,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a spider leg",
    other: "No"
  },
  messaging: {
    description: [
      "Often first noticed as just a large clump of moving snow, the greater ice spider resolves into a wide, low-slung spider three feet across and half again as long. Covered with thick, white hair to ward against the cold wind, the greater ice spider roams the snowfields looking for anything living it can web and consume."
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
