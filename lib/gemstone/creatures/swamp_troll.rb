{
  schema_version: 3,
  name: "swamp troll",
  noun: "",
  url: "https://gswiki.play.net/swamp_troll",
  picture: "",
  level: 14,
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
  max_hp: 170,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cairnfang Forest",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 173
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
    asg: "11N",
    immunities: [],
    melee: (49..78),
    ranged: nil,
    bolt: (59..89),
    udf: 104,
    bar_td: 49,
    cle_td: 57,
    emp_td: 57,
    pal_td: nil,
    ran_td: nil,
    sor_td: 53,
    wiz_td: nil,
    mje_td: 49,
    mne_td: 49,
    mjs_td: 57,
    mns_td: 57,
    mnm_td: 49,
    defensive_spells: [
      "Spirit Warding II (107)"
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
    skin: "a swamp troll scalp",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Huge and dangerous, the swamp troll towers above even a tall giantman. Grey skin so thick that it serves quite well as armor covers most of the troll, with tufts of thick hair sprouting here and there like weeds between cracked stones. A hideous grin splits its face displaying fangs crusted with dried blood and less guessable matter. No light of intellect glows in its narrow piggish eyes. The lust for slaughter and thirst for blood are what drive this hulkish beast's existence.</pre>\n\n<pre{{log2|margin-right=26em}}>The swamp troll is large in size and about nine feet high in its current state.</pre>"
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
