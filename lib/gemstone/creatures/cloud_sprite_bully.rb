{
  schema_version: 3,
  name: "cloud sprite bully",
  noun: "bully",
  url: "https://gswiki.play.net/cloud_sprite_bully",
  picture: "",
  level: 32,
  family: "Fey",
  type: "Biped",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: nil,
  sympathy: nil,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 302,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Cloud Forest",
      uids: [3219001..3219038]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Mace",
        as: (185..235)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Groin Kick"
      },
      {
        name: "Kneebash"
      },
      {
        name: "Footstomp"
      },
      {
        name: "Kick"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (190..267),
    ranged: (208..219),
    bolt: (208..219),
    udf: (202..308),
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (90..96),
    sor_td: 113,
    wiz_td: nil,
    mje_td: 131,
    mne_td: 131,
    mjs_td: nil,
    mns_td: 96,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Nonenchanted equipment immunity",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "Long, muscular legs support the small body of the bully. Her skin is nut brown and she has mustard yellow hair that falls to the small of her back in tangled, unwashed locks. She has big almond-shaped eyes that are oddly wide-set and a pointed nose that looks like a thorn sticking out of her round, plump face."
    ],
    arrival: [
      "Smacking one fist into {pronoun} opposite hand in a menacing manner, a cloud sprite bully wanders in.",
      "A cloud sprite bully darts out of the shadows! Giggling to {pronoun}, a cloud sprite bully quickly dashes to the {direction}.",
      "A cloud sprite bully darts out of the shadows! a cloud sprite bully spits a glob of yellowish saliva into {pronoun} hands and rubs {pronoun} together as if looking for a fight.",
      "A cloud sprite bully darts out of the shadows! Giggling madly, a cloud sprite bully lunges forward and attacks you with {pronoun} wooden mace!",
      "A cloud sprite bully darts out of the shadows! Whimpering softly, a cloud sprite bully hobbles {direction}."
    ],
    flee: [
      "A cloud sprite bully hobbles {direction}, whimpering."
    ],
    death: [],
    decay: [],
    search: [],
    spell_prep: [],
    attacks: {
      groin_kick: [
        "A cloud sprite bully kicks at your groin!"
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
