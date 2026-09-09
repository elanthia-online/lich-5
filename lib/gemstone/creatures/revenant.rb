{
  schema_version: 3,
  name: "revenant",
  noun: "revenant",
  url: "https://gswiki.play.net/revenant",
  picture: "",
  level: 4,
  family: "Ghost",
  type: "Biped",
  undead: true,
  blood: false,
  bones: false,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 57,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      uids: [14008040..14008070]
    },
    {
      name: "The Graveyard",
      uids: [18036..18040, 18042..18044]
    },
    {
      name: "unmapped",
      uids: [18041..18041, 18045..18046]
    },
    {
      name: "Cairnfang",
      uids: [630001..630014]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 57
      },
      {
        name: "Broadsword",
        as: 0
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 40
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (-33..-16),
    ranged: (-35..-19),
    bolt: (-35..-19),
    udf: (12..35),
    bar_td: 12,
    cle_td: 12,
    emp_td: 12,
    pal_td: (9..12),
    ran_td: 12,
    sor_td: 12,
    wiz_td: 12,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
    mnm_td: 12,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a broadsword",
    "a wooden shield",
    "some reinforced leather"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The revenant howls in pain, excruciatingly remembering its grisly demise. It presents a ghostly visage of skin shredded by the torturer's whip to display exposed muscles, shriveled organs, and protruding bones. This gaunt creature strikes quickly in its attempt to eradicate all that is living, thereby making sure its enemies die as well.\n\nLook:\nYou see a fairly typical revenant. It appears to be undead.\nIt appears to be in good shape.\nIt has a wooden shield, a broadsword and some reinforced leather (worn).\n\nAssess:\nThe revenant is medium in size and about five feet high in its current state."
    ],
    arrival: [
      "Out of thin air, a shadowy figure takes shape before your eyes and materializes into a revenant!",
      "A revenant just arrived."
    ],
    flee: [],
    death: [
      "The revenant slowly settles to the ground and begins to dissipate."
    ],
    decay: [
      "A revenant vanishes into thin air, leaving no trace behind."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A revenant swings {weapon} at you!"
      ]
    },
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
