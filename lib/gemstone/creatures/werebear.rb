{
  schema_version: 3,
  name: "werebear",
  noun: "",
  url: "https://gswiki.play.net/werebear",
  picture: "",
  level: 10,
  family: "Bear",
  type: "Quadruped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Corporeal undead"
  ],
  bcs: nil,
  max_hp: 150,
  speed: "10",
  height: nil,
  size: "",
  areas: [
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "Sentoph",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 130
      },
      {
        name: "Claw",
        as: 130
      },
      {
        name: "Charge (attack)",
        as: 140
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
    asg: "8N",
    immunities: [],
    melee: 57,
    ranged: nil,
    bolt: 75,
    udf: 85,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: 30,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 30,
    mjs_td: nil,
    mns_td: 30,
    mnm_td: 30,
    defensive_spells: [],
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
    skin: "a werebear paw",
    other: nil
  },
  messaging: {
    description: [
      "Smaller than a normal bear, the werebear still presents a menacing aspect. Eyes that glitter with a shred of their former humanity glare out at the world with undisguised rage and hate. Thick dark fur combined with a tough hide gives the beast a solid defense, and huge paws tipped with razor sharp claws give pause to even the well-armed adventurer."
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
