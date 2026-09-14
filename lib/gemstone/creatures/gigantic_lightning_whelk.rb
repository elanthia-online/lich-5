{
  schema_version: 3,
  name: "gigantic lightning whelk",
  noun: "whelk",
  url: "https://gswiki.play.net/gigantic_lightning_whelk",
  picture: "",
  level: 107,
  family: "Whelk",
  type: "",
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
  max_hp: 500,
  speed: 10,
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
        name: "Huge hooves",
        as: 519
      },
      {
        name: "Tusks",
        as: 519
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Headbutt"
      },
      {
        name: "Bull Rush"
      }
    ],
    special_abilities: [
      {
        name: "Shock Beam"
      },
      {
        name: "Snailguard"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: nil,
    ranged: nil,
    bolt: nil,
    udf: (538..952),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 464,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 489,
    mjs_td: nil,
    mns_td: 437,
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
    boxes: nil,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      ";Out of Shell\nThe lightning whelk's spiraled shell is a marvel of natural artistry. Each ridge and every curve shimmers with iridescent hues like a storm of empyrean color captured in glass. Beneath its luminous armor, the mollusk's incandescent flesh pulses with electrical charges that awaken stunning colors beneath its semitranslucent skin. In a striking contrast to its natural beauty, the whelk's underbelly emits a constant froth of bubbling mucus to facilitate its locomotion.\n\n;In Shell\nThe lightning whelk's spiraled shell is a marvel of natural artistry. Each ridge and every curve shimmers with iridescent hues like a storm of empyrean color captured in glass. Most of the whelk's body is coiled into its shell for protection, though its visible flesh is slightly incandescent and pulses with electrical charges that awaken stunning colors beneath its semitranslucent skin. In a striking contrast to its natural beauty, the whelk's underbelly emits a constant froth of bubbling mucus to facilitate its locomotion."
    ],
    arrival: [],
    flee: [
      "Warning hues flush through a gigantic lightning whelk's semitranslucent flesh as its head retreats into the safety of its opalescent shell."
    ],
    death: [
      "Chaotic pulses of color explode through a gigantic lightning whelk's flesh like fireworks as it collapses, letting out a pained rumble as it dies in a froth of bubbling mucus.",
      "Chaotic pulses of color explode through a gigantic lightning whelk's flesh like fireworks as it collapses.  It dies in a froth of bubbling mucus."
    ],
    decay: [],
    search: [
      "A gigantic lightning whelk pulses softly, radiance pulsing through {pronoun} body as {pronoun} antennae scan the shadows.",
      "A gigantic lightning whelk twitches {pronoun} antennae in opposite directions to scan the surroundings."
    ],
    spell_prep: [],
    attacks: {
      attack: [
        "A gigantic lightning whelk slams {pronoun} head into you!",
        "The gigantic lightning whelk slams into {target}, who is sent careening headlong into a nearby group of combatants as {target} falls to the ground!",
        "The gigantic lightning whelk slams into you, and you are sent careening into {target} as you fall to the ground!",
        "A gigantic lightning whelk rears back, emitting an awful gurgle. {Pronoun} opens {pronoun} mouth and spews a stream of clumpy white froth at you!"
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
