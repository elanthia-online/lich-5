{
  schema_version: 3,
  name: "bog spectre",
  noun: "",
  url: "https://gswiki.play.net/bog_spectre",
  picture: "",
  level: 47,
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
  bcs: true,
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Fethayl Bog",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 269
      },
      {
        name: "Ensnare",
        as: 275
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Corrupt Essence (703)",
        cs: 226
      },
      {
        name: "Disintegrate (705)"
      },
      {
        name: "Grasp of the Grave (709)"
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Gaze Attack"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "5",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: 228,
    udf: nil,
    bar_td: 182,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 201,
    wiz_td: nil,
    mje_td: 189,
    mne_td: (186..204),
    mjs_td: nil,
    mns_td: 186,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Defense I (401)",
      "Elemental Defense II (406)",
      "Spirit Defense (103)",
      "Spirit Warding I (101)",
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
    skin: nil,
    other: "Glowing violet essence shard"
  },
  messaging: {
    description: [
      "The bog spectre's misty form fades to a faint silhouette at times, the outlines of its form barely visible against its surroundings. Two malevolent eyes stare out from under its deeply hooded robe, each illuminated by an unholy crimson glow. Its thin, lanky arms end in unnaturally long taloned fingers, the semi-translucent claws still holding a twinge of glistening red on their surface. The creature is completely silent, its flickering form stalking with surprising speed and grace as it traverses the bog."
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
