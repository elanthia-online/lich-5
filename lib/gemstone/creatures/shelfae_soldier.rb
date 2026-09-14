{
  schema_version: 3,
  name: "shelfae soldier",
  noun: "soldier",
  url: "https://gswiki.play.net/shelfae_soldier",
  picture: "",
  level: 7,
  family: "Shelfae",
  type: "Hybrid",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: false,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 100,
  speed: 7,
  height: 5,
  size: "medium",
  areas: [
    {
      name: "Coastal Cliffs",
      uids: [84400..84409, 84416..84418]
    },
    {
      name: "Plains of Vornavis",
      uids: [4212301..4212324]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Trident",
        as: 102
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
    asg: "11",
    immunities: [],
    melee: 32,
    ranged: (3..18),
    bolt: (3..18),
    udf: (63..74),
    bar_td: 21,
    cle_td: 21,
    emp_td: 21,
    pal_td: (18..21),
    ran_td: 21,
    sor_td: 21,
    wiz_td: nil,
    mje_td: 21,
    mne_td: 21,
    mjs_td: (21..51),
    mns_td: (21..51),
    mnm_td: 21,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a trident"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: "a shelfae scale",
    other: "ayanad crystal",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A shelfae soldier thrusts with a trident at you!"
      ]
    },
    stand: [
      "A shelfae soldier stands back up with a sibilant hiss."
    ],
    description: [
      "The shelfae soldier is the vanguard of the shelfae reptilian forces. Bipedal, it stands approximately five feet tall with orange-tinged scales and clawed hands and feet. The shelfae soldier does not range very far from its commanding officer, and usually can be found guarding strategic points in the defensive system. It views the world through cold reptilian eyes and shows little mercy when confronting an enemy to its lands."
    ],
    arrival: [
      "A shelfae soldier just arrived."
    ],
    flee: [
      "A shelfae soldier runs {direction}."
    ],
    death: [
      "The shelfae soldier falls to the ground and dies.",
      "The shelfae soldier screams one last time and dies."
    ],
    decay: [
      "A soldier crumbles into dust."
    ],
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
