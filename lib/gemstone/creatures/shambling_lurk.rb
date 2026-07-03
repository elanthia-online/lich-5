{
  schema_version: 3,
  name: "shambling lurk",
  noun: "",
  url: "https://gswiki.play.net/shambling_lurk",
  picture: "",
  level: 97,
  family: "Zombie",
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
  max_hp: 550,
  speed: nil,
  height: nil,
  size: "",
  areas: [
    {
      name: "Sanctum",
      rooms: []
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: 450
      },
      {
        name: "Bite",
        as: "(Enraged) 530"
      }
    ],
    bolt_spells: [
      {
        name: "Web (118)",
        as: 417
      }
    ],
    warding_spells: [],
    offensive_spells: [
      {
        name: "Elemental Wave"
      }
    ],
    maneuvers: [],
    special_abilities: [
      {
        name: "Vomit"
      },
      {
        name: "Bite"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "1",
    immunities: [],
    melee: 350,
    ranged: (358..377),
    bolt: nil,
    udf: nil,
    bar_td: nil,
    cle_td: nil,
    emp_td: nil,
    pal_td: 342,
    ran_td: 352,
    sor_td: nil,
    wiz_td: nil,
    mje_td: 465,
    mne_td: 461,
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "Animate dead characters",
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  treasure: {
    coins: nil,
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: nil,
    other: nil
  },
  messaging: {
    description: [
      "Not dead so long that its body has begun to lose the unwinnable war against decay, a shambling lurk is firmly in the grip of rigor mortis.  Its face is paralyzed in a slack-jawed smile that reveals broken teeth and a dry and swollen tongue.  From the viridian firelight dancing in its eyes, it is clear that it is beyond the services of a cleric, except perhaps to grant the blessing of a swift release."
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
