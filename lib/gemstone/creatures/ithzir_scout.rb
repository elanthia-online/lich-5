{
  schema_version: 3,
  name: "Ithzir scout",
  noun: "scout",
  url: "https://gswiki.play.net/ithzir_scout",
  picture: "",
  level: 89,
  family: "Ithzir",
  type: "Biped",
  undead: false,
  blood: true,
  bones: true,
  limbs: true,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: true,
  boss: false,
  boss_type: nil,
  otherclass: [
    "Living",
    "Extraplanar"
  ],
  bcs: true,
  max_hp: 300,
  speed: 6,
  height: 6,
  size: "medium",
  areas: [
    {
      name: "Old Ta'Faendryl",
      uids: [17004001..17004028, 17004031..17004079, 17004160..17004168, 17004180..17004187, 17004190..17004195]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Broadsword",
        as: (414..436)
      },
      {
        name: "Closed fist",
        as: 402
      },
      {
        name: "Smash",
        as: (443..459)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Cheapshots"
      },
      {
        name: "Sweep"
      },
      {
        name: "Stomp"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (303..552),
    ranged: (291..444),
    bolt: (291..444),
    udf: (405..512),
    bar_td: nil,
    cle_td: (335..344),
    emp_td: (325..363),
    pal_td: (284..293),
    ran_td: (284..291),
    sor_td: (339..363),
    wiz_td: nil,
    mje_td: (368..429),
    mne_td: (368..429),
    mjs_td: (373..378),
    mns_td: (373..378),
    mnm_td: (273..279),
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [
    "a charcoal grey shield",
    "a curved crystal-edged blade",
    "a gleaming crystal-edged broadsword",
    "a gleaming steel broadsword",
    "some sleek grey brigandine"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: "crystal-edged weapons",
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    attacks: {
      attack: [
        "An Ithzir scout swings {weapon} at you!",
        "The Ithzir scout points at you for emphasis.",
        "An Ithzir seer suddenly opens Ithzir scout eyes and stares directly at you!",
        "The Ithzir scout cocks {pronoun} head at you."
      ],
      hurl: [
        "An Ithzir scout throws {weapon} at you!"
      ]
    },
    stand: [
      "An Ithzir scout rises to {pronoun} feet, {pronoun} green eyes blazing!"
    ],
    description: [
      "Wide, pupil-less green eyes peer about, quickly assessing both threats and terrain. The Ithzir scout stalks in a fluid, half-crouch that is as graceful as it is lightning fast, his whole demeanor underscoring his menace and obvious intelligence. The Ithzir scout is slightly taller than a human, and while his humanoid form is similar to scores of other races, the hairless, blue-skinned body is nonetheless alien in its appearance. The scout wears a charcoal grey tunic with no apparent identifiers of his station."
    ],
    arrival: [
      "An Ithzir initiate strides in, {pronoun} hands clasped before him.",
      "An Ithzir scout fades into view while striking!",
      "An Ithzir scout fades into view while attempting to strike, but fails to find an opening!",
      "An Ithzir scout staggers in, barely able to keep {pronoun} feet!"
    ],
    flee: [
      "An Ithzir scout slowly backs away with {pronoun} steel broadsword brandished menacingly in front of {pronoun}."
    ],
    death: [
      "The Ithzir scout twitches violently, then dies.",
      "The Ithzir scout vainly struggles to rise, then goes still.",
      "An Ithzir scout's body shimmers slightly, then fades from view like a dissipating phantom."
    ],
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
