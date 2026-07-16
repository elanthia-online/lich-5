{
  schema_version: 3,
  name: "black leopard",
  noun: "",
  url: "https://gswiki.play.net/black_leopard",
  picture: "",
  level: 15,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 140,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Grasslands",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 168
      },
      {
        name: "Bite",
        as: 168
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Pounce"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6N",
    immunities: [],
    melee: 150,
    ranged: nil,
    bolt: (82..85),
    udf: nil,
    bar_td: 45,
    cle_td: (42..51),
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 45,
    wiz_td: nil,
    mje_td: (39..45),
    mne_td: 45,
    mjs_td: 45,
    mns_td: 45,
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
    skin: "a black leopard paw",
    other: nil
  },
  messaging: {
    description: [
      "At first glance, the black leopard has pure black fur but upon the shifting of light, faint auburn rosette patterns fade in and out of sight against the sleek darkness. The only visible part of the leopard when she's stealthily hidden in the wilds is her deeply-toned amber eyes, which are always gazing warily at her surroundings. With the ability to retract her claws into her large padded paws, the black leopard is able to conceal her movement and stalk silently behind her prey with great success."
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
