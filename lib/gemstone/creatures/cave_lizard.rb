{
  schema_version: 3,
  name: "cave lizard",
  noun: "",
  url: "https://gswiki.play.net/cave_lizard",
  picture: "",
  level: 18,
  family: "Reptilian",
  type: "Quadruped",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 160,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Czeroth Caverns",
      rooms: []
    },
    {
      name: "Hornwort Cavern",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 193
      },
      {
        name: "Bite",
        as: 183
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [
      {
        name: "Tail Sweep"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "16N",
    immunities: [],
    melee: (149..178),
    ranged: nil,
    bolt: 147,
    udf: nil,
    bar_td: 54,
    cle_td: nil,
    emp_td: 54,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 54,
    mne_td: 54,
    mjs_td: 54,
    mns_td: 54,
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
    coins: false,
    magic_items: false,
    gems: true,
    boxes: false,
    skin: "a stone-grey lizard tail",
    other: nil
  },
  messaging: {
    description: [
      "<pre{{log2|margin-right=26em}}>When safe in the confines of its underground home, the cave lizard is easily mistaken for just another rock on the floor, albeit a rather long, thick rock.  Its low-slung body and stubby legs allow it to squeeze through cracks that would defy attempts by the smaller humanoid races.  A mottled, scaly hide of charcoal grey intermixed with deep crimson helps it hide in low light conditions.  Bright light reveals not only the more scintillating aspects of its crimson coloration but rows of razor-sharp teeth set in a protruding snout.  One should not fixate on the snout, though, lest the powerful tail of the cave lizard land a devastating blow.</pre>"
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
