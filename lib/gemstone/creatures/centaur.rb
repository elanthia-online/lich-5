{
  schema_version: 3,
  name: "centaur",
  noun: "",
  url: "https://gswiki.play.net/centaur",
  picture: "",
  level: 23,
  family: "Centaur",
  type: "Hybrid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: true,
  otherclass: [
    "Living",
    "Boss"
  ],
  bcs: true,
  max_hp: 260,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Darkstone Castle",
      rooms: []
    },
    {
      name: "Foggy Valley",
      rooms: []
    },
    {
      name: "Glo'antern Moor",
      rooms: []
    },
    {
      name: "Rambling Meadows",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Longsword",
        as: 208
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Kick"
      },
      {
        name: "Bull Rush"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: nil,
    ranged: (125..155),
    bolt: nil,
    udf: nil,
    bar_td: (69..75),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 69,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 69,
    mjs_td: nil,
    mns_td: 69,
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
    skin: "a centaur hide",
    other: "Glimmering blue essence shard"
  },
  messaging: {
    description: [
      "Seeming to be a blend of mannish torso upon the body of a light horse, the centaur has a certain charm and aura of mystery. That is, until you encounter one, for the centaur is a savage and wilder cousin to the great centaurs of legend and will lash out in terrible fury when it deems a threat is at hand. Their hide which varies in color from tan, black, white or roan is valued for its toughness and durability and thus, many will brave the danger of flying hooves and the threat held by these fierce creatures to gain this prize."
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
