{
  schema_version: 3,
  name: "mountain goat",
  noun: "goat",
  url: "https://gswiki.play.net/mountain_goat",
  picture: "",
  level: 17,
  family: "Caprine",
  type: "Quadruped",
  undead: false,
  blood: true,
  bones: true,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living"
  ],
  bcs: true,
  max_hp: 219,
  speed: 9,
  height: 3,
  size: "medium",
  areas: [
    {
      name: "Emerald Forest",
      uids: [13301170..13301191, 13301201..13301232]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite",
        as: (161..175)
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
    asg: "10N",
    immunities: [],
    melee: (99..167),
    ranged: (106..109),
    bolt: (106..109),
    udf: (131..154),
    bar_td: 51,
    cle_td: (45..51),
    emp_td: (51..59),
    pal_td: (48..57),
    ran_td: (45..51),
    sor_td: (48..57),
    wiz_td: nil,
    mje_td: 51,
    mne_td: 51,
    mjs_td: (51..57),
    mns_td: (51..57),
    mnm_td: (45..54),
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
    magic_items: nil,
    gems: nil,
    boxes: nil,
    skin: "a goat hoof",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The mountain goat is a blunt squarish-looking animal with a rather short body and humped shoulders. The narrow head has a black muzzle, sharp pointed ears and a double beard of long hair on her chin and throat. The white coat has a soft, woolly, three to four inches thick undercoat. Long coarse guard hairs, up to seven inches long, form heavy mats over the shoulders and hips giving a humped appearance. The coat grows to within eight inches of each hoof, where it abruptly stops giving the appearance of the goat wearing pants. As the days become longer and the weather warmer, she begins to shed her heavy winter coat and replaces it with a short summer coat that is yellowish in color. Black hooves accent her normal white coat and are equipped with cushioned skid-proof pads for grip and traction on steep rocky surfaces. Atop her head, slender, black shiny horns rise in a smooth backward curve to a length of ten to twelve inches. Rings can be seen around each horn indicative of the number of winters she has survived."
    ],
    arrival: [
      "A mountain goat just arrived.",
      "A mountain goat trots in!"
    ],
    flee: [
      "A mountain goat trots {direction}.",
      "A mountain goat brays as {pronoun} slowly backs away."
    ],
    death: [
      "The mountain goat collapses to the ground, emits a final bray, and dies.",
      "The mountain goat lets out a final agonized bray and dies."
    ],
    decay: [
      "A mountain goat decays into a pile of fur and bone."
    ],
    search: [],
    spell_prep: [],
    attacks: {
      bite: [
        "A mountain goat tries to bite you!"
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
