{
  schema_version: 3,
  name: "hapless charmed corsair",
  noun: "corsair",
  url: "https://gswiki.play.net/hapless_charmed_corsair",
  picture: "",
  level: 105,
  family: "Humanoid",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: nil,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: nil,
  max_hp: 375,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Sailor's Grief",
      uids: [7150101..7150105, 7150115..7150116, 7150201..7150229, 7150301..7150325, 7150328..7150329]
    },
    {
      name: "unmapped",
      uids: [7150117..7150117, 7150326..7150327]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Cudgel",
        as: 605
      },
      {
        name: "Huge black alloy greatsword",
        as: 592
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Intensity (1130)"
      }
    ],
    maneuvers: [
      {
        name: "Bearhug"
      },
      {
        name: "Haymaker"
      },
      {
        name: "Berserk"
      },
      {
        name: "Slippery Mind"
      }
    ],
    special_abilities: [
      {
        name: "Cyclonic Slash"
      },
      {
        name: "Grasping Ward"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: (564..892),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 424,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 448,
    mjs_td: nil,
    mns_td: 386,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
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
      "Only tattered rags are left of the corsair's colorfully piratical attire. The remnants are faded by sun and stained with salt, their ragged holes revealing sunburnt skin beneath. Despite her tatterdemain state and the ravages of the elements to her exposed flesh, the charmed corsair's expression is dispassionate and her eyes devoid of sentience. A faint aura of magic tinged an unsavory pink enshrouds her."
    ],
    arrival: [
      "A hapless charmed corsair flies into a sudden fit of rage!"
    ],
    flee: [],
    death: [
      "The fury twitching across a hapless charmed corsair's features dies away, leaving him looking empty and mindless.",
      "A hapless charmed corsair crumples, a last horrible moment of clarity shining in {pronoun} eyes before death takes {pronoun}."
    ],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      bearhug: [
        "A hapless charmed corsair charges towards you and attempts to grasp you in a ferocious bearhug!"
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
