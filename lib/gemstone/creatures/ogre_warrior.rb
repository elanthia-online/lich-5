{
  schema_version: 3,
  name: "ogre warrior",
  noun: "",
  url: "https://gswiki.play.net/ogre_warrior",
  picture: "",
  level: 20,
  family: "Ogre",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 250,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Neartofar Forest",
      rooms: []
    },
    {
      name: "Wehntoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: 201
      },
      {
        name: "Military pick",
        as: 193
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Sunder Shield"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (97..165),
    ranged: (78..102),
    bolt: nil,
    udf: nil,
    bar_td: 60,
    cle_td: 60,
    emp_td: nil,
    pal_td: 60,
    ran_td: 60,
    sor_td: 60,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 60,
    mjs_td: nil,
    mns_td: 60,
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
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "an ogre tooth",
    other: "Glimmering blue essence shard"
  },
  messaging: {
    description: [
      "The ogre warrior's bulging muscles and long arms give it an advantage in any encounter it might have. The heavy, rock hard skin serves equally well as armor or to just keep itself dry from the elements. Dark, smoking eyes glare out as it challenges any to oppose it."
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
