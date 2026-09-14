{
  schema_version: 3,
  name: "burly reiver",
  noun: "reiver",
  url: "https://gswiki.play.net/burly_reiver",
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
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 269,
  speed: 12,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Luinne Bheinn",
      uids: [4251110..4251111]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Steel dirk",
        as: 232
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
    melee: (99..114),
    ranged: (76..103),
    bolt: (76..103),
    udf: (133..138),
    bar_td: nil,
    cle_td: 72,
    emp_td: 72,
    pal_td: (69..72),
    ran_td: 72,
    sor_td: 72,
    wiz_td: nil,
    mje_td: 72,
    mne_td: 72,
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
    "a steel dirk",
    "a steel rimmed shield",
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
    description: [
      "A reiver stands tall and proud. Moss-green eyes dominate its strong face and tousled, dark hair crown its head. The reiver is well-muscled and toned, with calloused hands used to the wielding of weapons. Forged by a hard history and a harsh climate, reivers are tough fighters with a sense of honor and duty. Normally calm and amiable, the reiver's visage is thunderous when kith and kin are threatened or there are krolvins lurking."
    ],
    arrival: [
      "A burly reiver just came through a red door."
    ],
    flee: [
      "A burly reiver heads {direction}.",
      "A burly reiver just went through a red door."
    ],
    death: [
      "The reiver takes one last breath, then dies.",
      "The burly reiver falls to the ground motionless."
    ],
    decay: [
      "A burly reiver turns to dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "A burly reiver swings {weapon} at you!"
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
