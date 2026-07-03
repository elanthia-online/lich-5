{
  schema_version: 3,
  name: "moor eagle",
  noun: "",
  url: "https://gswiki.play.net/moor_eagle",
  picture: "",
  level: 35,
  family: "Bird",
  type: "Avian",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 400,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Shattered Moors",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 259
      },
      {
        name: "Impale",
        as: 239
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
    asg: nil,
    immunities: [],
    melee: (171..198),
    ranged: 173,
    bolt: nil,
    udf: nil,
    bar_td: 109,
    cle_td: nil,
    emp_td: 121,
    pal_td: nil,
    ran_td: nil,
    sor_td: 128,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 134,
    mjs_td: nil,
    mns_td: 121,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "moor eagle talon",
    other: nil
  },
  messaging: {
    description: [
      "Wide, snow white wings spread ten feet across as the moor eagle soars in flight. Pale yellow feet extend below the bird's light grey, feathered body, the feet displaying razor-sharp talons that look long and strong enough to powerfully grasp most anything the eagle might encounter. A large, hooked beak protrudes from the moor eagle's head. In contrast to the muted colors on the rest of the moor eagle, the eagle's eyes are a striking sky blue."
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
