{
  schema_version: 3,
  name: "tundra giant",
  noun: "giant",
  url: "https://gswiki.play.net/tundra_giant",
  picture: "",
  level: 34,
  family: "Giant",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Element-based"
  ],
  bcs: true,
  max_hp: 485,
  speed: nil,
  height: 15,
  size: "huge",
  areas: [
    {
      name: "Ice Plains",
      uids: [4127021..4127034]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw (attack)",
        as: 235
      }
    ],
    bolt_spells: [
      {
        name: "Major Cold (907)",
        as: 193
      }
    ],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Ground Slam"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: (137..216),
    ranged: (90..143),
    bolt: (90..143),
    udf: (205..278),
    bar_td: nil,
    cle_td: (113..123),
    emp_td: nil,
    pal_td: (99..109),
    ran_td: (99..108),
    sor_td: (121..139),
    wiz_td: nil,
    mje_td: (132..141),
    mne_td: (132..141),
    mjs_td: (114..124),
    mns_td: (114..124),
    mnm_td: (109..117),
    defensive_spells: [
      "Spirit Warding I (101)",
      "Spirit Defense (103)",
      "Spirit Warding II (107)"
    ],
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
    skin: "a tundra giant tooth",
    other: [
      "Glimmering blue essence shard",
      "essence of water"
    ],
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Standing twice as tall as as the tallest giantman, the ice giant trails frost and snow in its wake. Seemingly carved from living ice and snow, icy blue eyes set beneath a heavily furrowed brow and a tangled mop of icy blue hair provide a splash of color against the ice giant's dull white frost-covered skin."
    ],
    arrival: [
      "A tundra giant lumbers in, followed by a swirling snowstorm!"
    ],
    flee: [
      "A tundra giant lumbers {direction}, followed by a swirling snowstorm."
    ],
    death: [
      "The tundra giant cries out in cold agony one last time and dies.",
      "The tundra giant falls to the ground motionless."
    ],
    decay: [],
    search: [],
    spell_prep: [
      "A tundra giant mutters an incantation."
    ],
    stand: [
      "A tundra giant throws {pronoun} head back and howls, shaking off the stun!"
    ],
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
