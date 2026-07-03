{
  schema_version: 3,
  name: "war troll",
  noun: "",
  url: "https://gswiki.play.net/war_troll",
  picture: "",
  level: 18,
  family: "Troll",
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
  max_hp: 230,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Danjirland",
      rooms: []
    },
    {
      name: "Old Mine Road",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Two-handed sword",
        as: (175..211)
      },
      {
        name: "War hammer",
        as: (175..211)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Attack strength boost"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "various",
    immunities: [],
    melee: (50..66),
    ranged: nil,
    bolt: 53,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: 69,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: (61..69),
    mne_td: (61..69),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Spirit Warding II (107)"
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Health regeneration",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a troll heart",
    other: nil
  },
  messaging: {
    description: [
      "Huge and dangerous, the war troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.\n\nAppraisal:\nThe war troll is large in size, about ten feet high in his current state, appears to be of hardy constitution, is in an offensive stance, and is in relatively good shape."
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
