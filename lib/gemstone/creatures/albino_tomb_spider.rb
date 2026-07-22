{
  schema_version: 3,
  name: "albino tomb spider",
  noun: "",
  url: "https://gswiki.play.net/albino_tomb_spider",
  picture: "",
  level: 8,
  family: "Arachnid",
  type: "Arachnid",
  undead: false,
  has_blood: nil,
  has_bones: nil,
  muggable: nil,
  boss: false,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 83,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "The Graveyard",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Claw",
        as: 116
      },
      {
        name: "Pincer (attack)",
        as: 116
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [],
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
    melee: (71..82),
    ranged: nil,
    bolt: (47..56),
    udf: nil,
    bar_td: 24,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: nil,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 24,
    mne_td: 24,
    mjs_td: nil,
    mns_td: nil,
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
    gems: false,
    boxes: false,
    skin: "multi-faceted tomb spider eye",
    other: nil
  },
  messaging: {
    description: [
      "Glowing an eerie, pale white, the tomb spider clambers through underground tunnels, grottos and caves in search of anything alive it can trap and consume. Its long, thin forelegs reach out to grasp and drag potential food back to the glistening fangs, while its shorter, muscular back legs propel it forward with surprising speed. Totally hairless, the tomb spider gazes around through the only bodily part that has any color--its oversized crimson eyes."
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
