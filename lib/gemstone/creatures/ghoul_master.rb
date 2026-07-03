{
  schema_version: 3,
  name: "ghoul master",
  noun: "",
  url: "https://gswiki.play.net/ghoul_master",
  picture: "",
  level: 16,
  family: "Ghoul",
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
  max_hp: 145,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Graveyard",
      rooms: []
    },
    {
      name: "Plains of Bone",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 137
      },
      {
        name: "Claw",
        as: 147
      },
      {
        name: "Pound (attack)",
        as: 137
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
    asg: "14",
    immunities: [],
    melee: 81,
    ranged: nil,
    bolt: 38,
    udf: 211,
    bar_td: 48,
    cle_td: 48,
    emp_td: nil,
    pal_td: 48,
    ran_td: 48,
    sor_td: 48,
    wiz_td: nil,
    mje_td: 48,
    mne_td: 48,
    mjs_td: nil,
    mns_td: 48,
    mnm_td: 48,
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
    skin: "a ghoul finger",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>Broader and taller then the more common ghouls, this one stands with some cold bearing of command and power.  Tattered rags of velvet and silk still drape the corrupt form and a keen light of evil will and force dominates the ruined face now rotting and festered.  The aura of its power tingles along your nerves and brings a cold sweat to your brow as you gaze into eyes, now vacant, which seem to stare back at you with cruel disdain.</pre>\n\nThe ghoul master is large in size and about seven feet high in its current state."
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
