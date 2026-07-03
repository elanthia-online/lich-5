{
  schema_version: 3,
  name: "hisskra shaman",
  noun: "",
  url: "https://gswiki.play.net/hisskra_shaman",
  picture: "",
  level: 33,
  family: "Hisskra",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Ruined Tower",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trident",
        as: 222
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 165
      },
      {
        name: "Mana Disruption (702)",
        cs: 165
      }
    ],
    offensive_spells: [
      {
        name: "Sounds (607)"
      },
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (238..259),
    ranged: nil,
    bolt: nil,
    udf: 225,
    bar_td: 112,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 128,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 135,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [
      "Natural Colors",
      "Resist Elements",
      "Spirit Defense",
      "Spirit Warding I",
      "Spirit Warding II"
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
    skin: "hisskra tooth",
    other: nil
  },
  messaging: {
    description: [
      "Nearly as tall as a typical human, the humanoid reptilian hisskra shares many characteristics with mankind. A long snout filled with an array of sharp teeth dominates the hisskra's facial features, giving him the appearance of a bipedal iguana. Well-defined pectorals and a muscular torso are nearly man-like, but for the dull, dark green scales that fade to a paler shade at the throat, and the ridge of mottled, boney spines that runs from between the hisskra shaman's shoulder blades to the tip of his four-foot tail. The hisskra's muscular limbs end in thick-fingered, partially-webbed hands and feet tipped with blackened claws, which are formidable weapons should the creature lose his more civilized martial implements. A primitive necklace formed of the bones of various sea creatures hangs around the shaman's neck, signifying his rank."
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
