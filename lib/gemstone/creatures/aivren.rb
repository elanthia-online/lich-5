{
  schema_version: 3,
  name: "aivren",
  noun: "",
  url: "https://gswiki.play.net/aivren",
  picture: "",
  level: 86,
  family: "Aivren",
  type: "Avian",
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
  max_hp: 300,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Rift",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite (attack)",
        as: 398
      },
      {
        name: "Claw (attack)",
        as: 378
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8",
    immunities: [],
    melee: (300..400),
    ranged: nil,
    bolt: 335,
    udf: nil,
    bar_td: 320,
    cle_td: 338,
    emp_td: 332,
    pal_td: 289,
    ran_td: nil,
    sor_td: 354,
    wiz_td: nil,
    mje_td: 373,
    mne_td: nil,
    mjs_td: 332,
    mns_td: 332,
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
    skin: "an aivren gizzard",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=27em}}>Leathery, ochre wings extending as wide as a giantman is tall, the aivren wheels and swoops with amazing dexterity.  The aivren flies low over the landscape, snapping up anything remotely edible in its long, pointed beak or sharp, descending claws.  Charcoal grey on the underbelly and a dusky ochre on the back, its speed often surprises its foes, allowing the aivren to strike the death blow before the opponent can react.</pre>"
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
