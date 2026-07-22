{
  schema_version: 3,
  name: "tomb troll",
  noun: "",
  url: "https://gswiki.play.net/tomb_troll",
  picture: "",
  level: 52,
  family: "Troll",
  type: "Biped",
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
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Marsh Keep",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Morning star",
        as: (292..296)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Shield Bash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 196,
    udf: nil,
    bar_td: 177,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 214,
    wiz_td: nil,
    mje_td: 215,
    mne_td: 213,
    mjs_td: nil,
    mns_td: 188,
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
    skin: "troll thumb",
    other: nil
  },
  messaging: {
    description: [
      "Shorter than the common troll, but no less ugly, the tomb troll is squat and covered in a mottled and oily albino skin. Bare but for patches of lanky yellow strands of hair that cover the back, chest and arms of the troll, the tomb troll has adapted to a world far from the sun -- the darkness of crypts, the source of her favorite food. Fat, pointed ears extend from the side of her head, framing larger than normal silver eyes with horizontal slits set above a maw full of jagged teeth."
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
