{
  schema_version: 3,
  name: "ithzir seer",
  noun: "",
  url: "https://gswiki.play.net/ithzir_seer",
  picture: "",
  level: 97,
  family: "Ithzir",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: nil,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Old Ta'Faendryl",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Quarterstaff",
        as: 398
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit",
        as: 476
      },
      {
        name: "Telekinesis",
        as: 476
      },
      {
        name: "Web",
        as: 476
      }
    ],
    warding_spells: [
      {
        name: "Bone Shatter",
        cs: 423
      },
      {
        name: "Frenzy",
        cs: (411..431)
      },
      {
        name: "Mass Interference",
        cs: (411..431)
      },
      {
        name: "Silence",
        cs: (425..431)
      },
      {
        name: "Torment",
        cs: 411
      },
      {
        name: "Web",
        cs: 431
      }
    ],
    offensive_spells: [
      {
        name: "Spirit Strike"
      },
      {
        name: "Spiritual Abolition"
      },
      {
        name: "Bravery (211)"
      },
      {
        name: "Elemental Focus (513)"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Psionic stun"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: nil,
    ranged: 279,
    bolt: (369..386),
    udf: nil,
    bar_td: (373..385),
    cle_td: (371..431),
    emp_td: (378..398),
    pal_td: nil,
    ran_td: nil,
    sor_td: 431,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: (363..423),
    mnm_td: nil,
    defensive_spells: [
      "Minor Sanctuary (213)",
      "Self Control (613)",
      "Spirit Fog (106)",
      "Wall of Force (140)",
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)",
      "Spirit Shield (202)",
      "Spell Shield (219)",
      "Self Control (613)"
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
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The Ithzir seer carries an authoritative bearing, her arresting, pupil-less green eyes taking in her surroundings with both confidence and cunning.  Even when battle rages around her, each movement of the seer seems eerily effortless and calm.  The Ithzir seer is slightly taller than a human, and while her humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance.  The seer wears a crisply-cut, silvery-blue tunic with high shoulders and a deep vee-neck.  Emblazoned on the right breast of the tunic is a twelve-pointed golden star.</pre>"
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
