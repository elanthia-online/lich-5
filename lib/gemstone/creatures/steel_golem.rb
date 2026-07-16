{
  schema_version: 3,
  name: "steel golem",
  noun: "",
  url: "https://gswiki.play.net/steel_golem",
  picture: "",
  level: 20,
  family: "Golem",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [],
  bcs: true,
  max_hp: 190,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glatoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 178
      },
      {
        name: "Pound",
        as: 188
      },
      {
        name: "Stomp",
        as: 198
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Twin Hammerfists"
      }
    ],
    special_abilities: [
      {
        name: "Foot slam"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "19N",
    immunities: [],
    melee: (73..87),
    ranged: nil,
    bolt: 82,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: (55..67),
    wiz_td: nil,
    mje_td: (56..68),
    mne_td: (57..69),
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
    skin: "No",
    other: "crystal core (alchemy)"
  },
  messaging: {
    description: [
      "The squeal of rusty gears and the shriek of cracked pipes expelling steam is nearly deafening, but the sharp sound of a steel golem's claws rhythmically sharpening themselves against each other still grate distinctly throughout the area. Thick plates of armor cover the golem, but nothing could hide the mass of mechanized motion underneath. In a horrifying mimicry of life, a lining of sharp steel teeth are embedded within its large jaw, just underneath eye sockets that slowly expel a stream of black smoke."
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
