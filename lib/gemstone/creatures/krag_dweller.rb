{
  schema_version: 3,
  name: "krag dweller",
  noun: "",
  url: "https://gswiki.play.net/krag_dweller",
  picture: "",
  level: 72,
  family: "Dweller",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Wehntoph",
      rooms: []
    },
    {
      name: "Stormpeak",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Pound",
        as: 400
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Krag dweller boulder"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [
      "Dark Catalyst (719)",
      "Implosion (720)",
      "Fire",
      "Web (118)"
    ],
    melee: nil,
    ranged: nil,
    bolt: (204..229),
    udf: nil,
    bar_td: (246..264),
    cle_td: (278..281),
    emp_td: (274..286),
    pal_td: nil,
    ran_td: 230,
    sor_td: (280..301),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (274..277),
    mns_td: (274..277),
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
    skin: nil,
    other: "[[Essence of earth]]"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The krag dweller appears to be a cross between a troll and elemental rock.  It towers over 8 feet tall with massive limbs.  Jet black hairs grow between the plates of its brown scaly hide while long razor sharp fangs and claws provide the krag dweller with all the weapons it will ever need.  Even darker than the blackest night, its eyes reveal the smouldering malice within.</pre>"
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
