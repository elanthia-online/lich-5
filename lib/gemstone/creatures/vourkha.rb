{
  schema_version: 3,
  name: "vourkha",
  noun: "",
  url: "https://gswiki.play.net/vourkha",
  picture: "",
  level: 39,
  family: "Wraith",
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
  max_hp: 240,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Black Moor",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 252
      },
      {
        name: "Claw",
        as: 262
      }
    ],
    bolt_spells: [
      {
        name: "Minor Acid (904)",
        as: 217
      },
      {
        name: "Minor Fire (906)",
        as: 217
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: (151..243),
    ranged: nil,
    bolt: (155..163),
    udf: 195,
    bar_td: 135,
    cle_td: nil,
    emp_td: 148,
    pal_td: nil,
    ran_td: 126,
    sor_td: 149,
    wiz_td: nil,
    mje_td: 163,
    mne_td: 162,
    mjs_td: nil,
    mns_td: 148,
    mnm_td: nil,
    defensive_spells: [
      "Elemental Bias (508)",
      "Thurfel's Ward (503)"
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
    other: "Glowing violet essence dust,"
  },
  messaging: {
    description: [
      "Empty black soulless eyes gaze from the gaunt, grey form of the wraithlike vourkha. His thin-lipped mouth gaped in a silent howl, he grasps at the fetid air with gnarled, clawed hands as he glides just above the ground, trailing tendrils of thick white ectoplasm that seem to seep from his shredded clothing. The creature seems to fade in and out of corporeal existence as if he walked in an eternal patch of shadow."
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
