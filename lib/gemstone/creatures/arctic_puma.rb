{
  schema_version: 3,
  name: "arctic puma",
  noun: "puma",
  url: "https://gswiki.play.net/arctic_puma",
  picture: "",
  level: 15,
  family: "Feline",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 135,
  speed: nil,
  height: 3,
  size: "small",
  areas: [
    {
      name: "Abbey",
      uids: [4132001..4132010]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 168
      },
      {
        name: "Bite",
        as: 168
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1N",
    immunities: [],
    melee: (106..166),
    ranged: (113..139),
    bolt: (113..139),
    udf: (133..190),
    bar_td: (39..51),
    cle_td: (42..45),
    emp_td: (37..45),
    pal_td: (39..45),
    ran_td: (39..45),
    sor_td: (39..51),
    wiz_td: nil,
    mje_td: (39..51),
    mne_td: (39..51),
    mjs_td: (39..54),
    mns_td: (39..54),
    mnm_td: (45..51),
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
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a white puma hide",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The arctic puma is a muscular and athletic animal. Covered with a uniform coat of greyish-brown fur, her long, lithe body is equipped with powerful legs, displaying a proportionately greater difference in the length of the forelegs compared to the extenuated hind legs. The feline's head is topped with rounded ears, and a very long, balancing tail completes the puma's physique."
    ],
    arrival: [
      "An arctic puma scampers in!"
    ],
    flee: [
      "An arctic puma scampers {direction}."
    ],
    death: [
      "The arctic puma crumples to the ground and dies.",
      "The arctic puma lets out a final caterwaul and dies."
    ],
    decay: [
      "An arctic puma decays into a compost of fangs, fur and claws."
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
