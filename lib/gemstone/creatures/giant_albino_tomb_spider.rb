{
  schema_version: 3,
  name: "giant albino tomb spider",
  noun: "spider",
  url: "https://gswiki.play.net/giant_albino_tomb_spider",
  picture: "",
  level: 30,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 350,
  speed: 8,
  height: 3,
  size: "large",
  areas: [
    {
      name: "The Graveyard",
      uids: [2162113..2162122]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Ensnare",
        as: 222
      },
      {
        name: "Bite",
        as: 212
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Web"
      }
    ],
    special_abilities: [
      {
        name: "Web"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12N",
    immunities: [],
    melee: nil,
    ranged: 100,
    bolt: 93,
    udf: (132..226),
    bar_td: nil,
    cle_td: 99,
    emp_td: 101,
    pal_td: (87..90),
    ran_td: nil,
    sor_td: (102..105),
    wiz_td: nil,
    mje_td: nil,
    mne_td: nil,
    mjs_td: (98..101),
    mns_td: (98..101),
    mnm_td: 90,
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
    coins: false,
    magic_items: false,
    gems: false,
    boxes: false,
    skin: "a sheer white spider mandible",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glowing an eerie, pale white, the albino tomb spider clambers through underground tunnels, grottos and caves in search of anything alive it can trap and consume. Its long, thin forelegs reach out to grasp and drag potential food back to the glistening fangs, while its shorter, muscular back legs propel it forward with surprising speed. Totally hairless, the albino tomb spider gazes around through the only bodily part that has any color--its oversized crimson eyes."
    ],
    arrival: [],
    flee: [
      "A giant albino tomb spider scurries {direction}."
    ],
    death: [
      "The albino tomb spider collapses to the ground and dies.",
      "The albino tomb spider's body jerks one last time and dies."
    ],
    decay: [
      "A giant albino tomb spider's legs shrivel up beneath it as it decays into dust.",
      "An albino tomb spider's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A giant albino tomb spider tries to bite you!"
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
