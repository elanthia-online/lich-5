{
  schema_version: 3,
  name: "moaning spirit",
  noun: "",
  url: "https://gswiki.play.net/moaning_spirit",
  picture: "",
  level: 28,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 225,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Castle Anwyn",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  spawns: [
    { zone: 2150, count: 1, uid_ranges: [[2150002, 2150007]] },
    { zone: 4285, count: 1, uid_ranges: [[4285004, 4285008], [4285013, 4285013], [4285024, 4285025]] }
  ],
  attack_attributes: {
    physical_attacks: [],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (150..167),
    ranged: (174..188),
    bolt: (174..188),
    udf: 165,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 100,
    mne_td: nil,
    mjs_td: nil,
    mns_td: nil,
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
    other: nil
  },
  messaging: {
    description: [
      "Intense hatred for those living drives the moaning spirit to traverse the bounds of space to attack its enemies. Crying out in constant pain, it marshals magic, claw and fist against its foes, destroying relentlessly to sate the desires of the forces that bind it, then returning whence it came to await the intrusion of another living creature. Its semi-transparent countenance is passably humanoid, save for the eagle-like claws replacing what would normally be the human's feet."
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
