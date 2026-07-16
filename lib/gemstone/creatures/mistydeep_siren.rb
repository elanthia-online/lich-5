{
  schema_version: 3,
  name: "mistydeep siren",
  noun: "",
  url: "https://gswiki.play.net/mistydeep_siren",
  picture: "",
  level: 2,
  family: "Fey",
  type: "Biped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 42,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Toadwort",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger",
        as: 50
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Calm (201)",
        cs: 10
      },
      {
        name: "Vibration Chant (1002)",
        cs: 2
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: (10..30),
    ranged: 7,
    bolt: (7..28),
    udf: nil,
    bar_td: 6,
    cle_td: nil,
    emp_td: 6,
    pal_td: nil,
    ran_td: 6,
    sor_td: 6,
    wiz_td: nil,
    mje_td: 6,
    mne_td: 6,
    mjs_td: nil,
    mns_td: 6,
    mnm_td: nil,
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
    other: "Pristine nymph's hair"
  },
  messaging: {
    description: [
      "The Mistydeep siren's pale eyes are initially glazed like two frosted, opaque panes of glass but they slowly melt to a warm blue as she transfixes her gaze onto her victims. She uses her melodious voice to allure, along with innocent blue eyes, whispering soft promises of pleasure to entice victims into her control. From a distance away, the Mistydeep siren looks like beautiful maiden with softly draping robes walking aimlessly along the shorelines but without the influence of glamor, it becomes obvious this is no helpless maiden. Her bluish corpselike skin and milky eyes is a dead give away of her true nature to any wary adventurer."
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
