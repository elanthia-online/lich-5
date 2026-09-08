{
  schema_version: 3,
  name: "veteran reiver",
  noun: "reiver",
  url: "https://gswiki.play.net/veteran_reiver",
  picture: "",
  level: 24,
  family: "Reiver",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
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
  max_hp: 270,
  speed: 12,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Luinne Bheinn",
      uids: [4251011..4251039]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Old claidhmore",
        as: 207
      },
      {
        name: "Unknown",
        as: 207
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
    melee: (89..116),
    ranged: (104..116),
    bolt: (104..116),
    udf: 137,
    bar_td: nil,
    cle_td: 72,
    emp_td: (61..72),
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 72,
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: 72,
    mns_td: 72,
    mnm_td: 72,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a threadbare dun tartan cloak",
    "an old claidhmore",
    "some full plate"
  ],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: nil,
    other: "glimmering blue essence shard",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "A veteran reiver swings {weapon} at you!",
        "A veteran reiver swings an old claidhmore at {target}!"
      ]
    },
    stand: [
      "A veteran reiver stands up and dusts {reflexive} off."
    ],
    description: [
      "The reiver stands tall and proud. Moss-green eyes dominate the strong face and tousled, dark hair crowns the head. The reiver is well-muscled and toned, with calloused hands used to the wielding of weapons. Forged by a hard history and a harsh climate, the reiver is a tough fighter with a sense of honor and duty. Normally calm and amiable, the reiver's visage is thunderous when kith and kin are threatened or there are krolvins lurking."
    ],
    arrival: [
      "A veteran reiver just arrived.",
      "A veteran reiver just came through a red door."
    ],
    flee: [
      "A veteran reiver heads {direction}."
    ],
    death: [
      "The reiver takes one last breath, then dies.",
      "The veteran reiver falls to the ground motionless."
    ],
    decay: [
      "A veteran reiver turns to dust."
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
