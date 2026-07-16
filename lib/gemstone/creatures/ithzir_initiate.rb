{
  schema_version: 3,
  name: "ithzir initiate",
  noun: "",
  url: "https://gswiki.play.net/ithzir_initiate",
  picture: "",
  level: 91,
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
  max_hp: 240,
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
        as: 433
      }
    ],
    bolt_spells: [
      {
        name: "Fire Spirit (111)",
        as: 407
      },
      {
        name: "Web (118)",
        as: 407
      }
    ],
    warding_spells: [
      {
        name: "Bind (214)",
        cs: 386
      },
      {
        name: "Divine Fury (317)",
        cs: 386
      },
      {
        name: "Divine Wrath (335)",
        cs: 386
      },
      {
        name: "Fervent Reproach (312)",
        cs: 386
      },
      {
        name: "Mass Interference (217)",
        cs: 386
      },
      {
        name: "Web (118)",
        cs: 398
      }
    ],
    offensive_spells: [
      {
        name: "Heroism (215)"
      },
      {
        name: "Spirit Strike (117)"
      }
    ],
    maneuvers: [
      {
        name: "Mind Stun"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: (362..387),
    udf: nil,
    bar_td: (351..363),
    cle_td: (370..380),
    emp_td: 366,
    pal_td: nil,
    ran_td: nil,
    sor_td: 395,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: nil,
    mns_td: (357..373),
    mnm_td: nil,
    defensive_spells: [
      "Lesser Shroud (120)",
      "Minor Sanctuary (213)",
      "Spell Shield (219)",
      "Spirit Defense (103)",
      "Spirit Shield (202)",
      "Spirit Warding I (101)",
      "Spirit Warding II (107)",
      "Wall of Force (140)"
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
      "The Ithzir initiate carries herself with a humble bearing, her arresting, pupil-less green eyes taking in her surroundings with confidence and surety. Even when battle rages around her, each movement of the initiate seems eerily effortless and calm. The Ithzir initiate is slightly taller than a human, and while her humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance. The initiate wears a crisply-cut, blue tunic with a green palm-print emblazoned on the right breast."
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
