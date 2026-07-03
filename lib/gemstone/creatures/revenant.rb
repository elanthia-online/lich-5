{
  schema_version: 3,
  name: "revenant",
  noun: "",
  url: "https://gswiki.play.net/revenant",
  picture: "",
  level: 4,
  family: "Ghost",
  type: "Biped",
  undead: true,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Non-corporeal undead"
  ],
  bcs: nil,
  max_hp: 57,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Glaise Cnoc Cemetery",
      rooms: []
    },
    {
      name: "Cairnfang Forest",
      rooms: []
    },
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Closed fist",
        as: 57
      },
      {
        name: "Broadsword",
        as: 0
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Blood Burst (701)",
        cs: 40
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "7N",
    immunities: [],
    melee: "-29",
    ranged: nil,
    bolt: "-35",
    udf: 22,
    bar_td: 12,
    cle_td: 12,
    emp_td: nil,
    pal_td: nil,
    ran_td: 12,
    sor_td: 12,
    wiz_td: 12,
    mje_td: 12,
    mne_td: 12,
    mjs_td: 12,
    mns_td: 12,
    mnm_td: 12,
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
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>The revenant howls in pain, excruciatingly remembering its grisly demise.  It presents a ghostly visage of skin shredded by the torturer's whip to display exposed muscles, shriveled organs, and protruding bones.  This gaunt creature strikes quickly in its attempt to eradicate all that is living, thereby making sure its enemies die as well.</pre>\n\nLook:\n<pre{{log2|margin-right=26em}}>You see a fairly typical revenant.  It appears to be undead.\nIt appears to be in good shape.\nIt has a wooden shield, a broadsword and some reinforced leather (worn).</pre>\n\nAssess:<br>\n<pre{{log2|margin-right=26em}}>The revenant is medium in size and about five feet high in its current state.</pre>"
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
