{
  schema_version: 3,
  name: "rotting krolvin pirate",
  noun: "",
  url: "https://gswiki.play.net/rotting_krolvin_pirate",
  picture: "",
  level: 18,
  family: "Krolvin",
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
  max_hp: 210,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Citadel",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Handaxe",
        as: 173
      },
      {
        name: "Trident",
        as: 173
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Trip"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "11",
    immunities: [],
    melee: (95..116),
    ranged: 64,
    bolt: (57..60),
    udf: 122,
    bar_td: 54,
    cle_td: 54,
    emp_td: 56,
    pal_td: nil,
    ran_td: nil,
    sor_td: 54,
    wiz_td: nil,
    mje_td: (51..60),
    mne_td: (51..60),
    mjs_td: (51..60),
    mns_td: (51..60),
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Gnarled white hair drapes in locks over the krolvin pirate's face, which is fixed in a constant murderous leer.  The pirate's puffy grayish-blue skin is slashed and punctured with what must have been mortal wounds, but the foul creature before you pays the ancient injuries no heed as she seeks to continue her plundering ways well beyond the grave.</pre>"
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
