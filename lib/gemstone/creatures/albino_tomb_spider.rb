{
  schema_version: 3,
  name: "albino tomb spider",
  noun: "spider",
  url: "https://gswiki.play.net/albino_tomb_spider",
  picture: "",
  level: 8,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  blood: true,
  bones: false,
  limbs: nil,
  witherable: true,
  sympathy: false,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 83,
  speed: 10,
  height: 2,
  size: "medium",
  areas: [
    {
      name: "The Graveyard",
      uids: [2162113..2162122]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: (106..116)
      },
      {
        name: "Pincer (attack)",
        as: 116
      },
      {
        name: "Pincer",
        as: 116
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
    asg: "1N",
    immunities: [],
    melee: (56..147),
    ranged: (48..69),
    bolt: (47..69),
    udf: (87..145),
    bar_td: 24,
    cle_td: 24,
    emp_td: 24,
    pal_td: (21..24),
    ran_td: 24,
    sor_td: 24,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: (60..66),
    mns_td: (60..66),
    mnm_td: 24,
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
    skin: "multi-faceted tomb spider eye",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Glowing an eerie, pale white, the tomb spider clambers through underground tunnels, grottos and caves in search of anything alive it can trap and consume. Its long, thin forelegs reach out to grasp and drag potential food back to the glistening fangs, while its shorter, muscular back legs propel it forward with surprising speed. Totally hairless, the tomb spider gazes around through the only bodily part that has any color--its oversized crimson eyes."
    ],
    arrival: [],
    flee: [
      "An albino tomb spider scurries {direction}.",
      "An albino tomb spider hobbles {direction}."
    ],
    death: [
      "The tomb spider's body jerks one last time and dies.",
      "The tomb spider collapses to the ground and dies.",
      "The albino tomb spider collapses to the ground and dies.",
      "The albino tomb spider's body jerks one last time and dies."
    ],
    decay: [
      "An albino tomb spider's legs shrivel up beneath it as it decays into dust.",
      "A giant albino tomb spider's legs shrivel up beneath it as it decays into dust."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      attack: [
        "An albino tomb spider snaps at you with {pronoun} pincer!"
      ],
      bite: [
        "An albino tomb spider snaps at you with {pronoun} pincer!",
        "An albino tomb spider snaps at {target} with {pronoun} pincer!"
      ],
      claw: [
        "An albino tomb spider claws at you!"
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
