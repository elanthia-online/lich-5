{
  schema_version: 3,
  name: "lesser ghoul",
  noun: "",
  url: "https://gswiki.play.net/lesser_ghoul",
  picture: "",
  level: 1,
  family: "Ghoul",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: true,
  max_hp: 40,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 31
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
    asg: "1N",
    immunities: [],
    melee: 0,
    ranged: nil,
    bolt: "-3",
    udf: 44,
    bar_td: 3,
    cle_td: 3,
    emp_td: 3,
    pal_td: 3,
    ran_td: 3,
    sor_td: 3,
    wiz_td: 3,
    mje_td: 3,
    mne_td: 3,
    mjs_td: 3,
    mns_td: 3,
    mnm_td: 3,
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
    skin: nil,
    other: "ghoul nail"
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Resembling a decaying corpse more than anything else, the lesser ghoul is hunched over so that its long arms trail along the ground.  Sharp claw-like nails tip both hands and feet and the stench of corruption wafts thickly from the sodden rags of clothing that cling to its leprous body.  Strings of gnawed flesh drop from the creature's loose-lipped mouth as it continues to chew on something better left unknown.</pre>"
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
