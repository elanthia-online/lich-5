{
  schema_version: 3,
  name: "firethorn shoot",
  noun: "shoot",
  url: "https://gswiki.play.net/firethorn_shoot",
  picture: "",
  level: 44,
  family: "Plant",
  type: "Plantlife",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: false,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 260,
  speed: 7,
  height: 4,
  size: "medium",
  areas: [
    {
      name: "Fhorian Village",
      uids: [3030001..3030010, 3030035..3030043, 3030250..3030254]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare (attack)",
        as: 244
      },
      {
        name: "Stinger (attack)",
        as: 254
      },
      {
        name: "Stinger",
        as: 254
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Tangleweed (610)"
      }
    ],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "8N",
    immunities: [],
    melee: (172..224),
    ranged: (184..232),
    bolt: (184..232),
    udf: 238,
    bar_td: nil,
    cle_td: 159,
    emp_td: 158,
    pal_td: (131..134),
    ran_td: 134,
    sor_td: 167,
    wiz_td: nil,
    mje_td: (176..177),
    mne_td: (176..177),
    mjs_td: 158,
    mns_td: 158,
    mnm_td: 132,
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
    magic_items: nil,
    gems: true,
    boxes: nil,
    skin: "a pulsating firethorn shoot",
    other: "glowing violet essence dust",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The firethorn shoot is comprised of a light brown, round, bamboo-like stalk rising off flexible roots. Near the top, several leafy green fronds, laden with thorns, curl away from the main stalk. A mobile, half-intelligent plant, the firethorn shoot ambles about looking for carriers in which to implant its thorny seeds in the hope that they will be taken far from the original plant to grown a new firethorn shoot. Unfortunately, the implantation process often kills the carrier."
    ],
    arrival: [
      "A firethorn shoot shambles in.",
      "A firethorn shoot just arrived."
    ],
    flee: [
      "A firethorn shoot heads {direction}.",
      "A firethorn shoot just went across a footbridge."
    ],
    death: [
      "The firethorn shoot falls to the ground and dies.",
      "The firethorn shoot twitches one last time and dies."
    ],
    decay: [
      "A firethorn shoot decays into compost."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A firethorn shoot stabs at you with {pronoun} stinger!",
        "A firethorn shoot stabs at {target} with {pronoun} stinger!",
        "The shoot is too easy for the likes of you!",
        "A firethorn shoot tries to ensnare {target}!"
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
