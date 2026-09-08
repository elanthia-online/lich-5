{
  schema_version: 3,
  name: "chitinous kiramon myrmidon",
  noun: "myrmidon",
  url: "https://gswiki.play.net/chitinous_kiramon_myrmidon",
  picture: "",
  level: 102,
  family: "Kiramon",
  type: "Insect",
  undead: false,
  blood: nil,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  bcs: true,
  max_hp: 500,
  speed: 10,
  height: 7,
  size: "large",
  areas: [
    {
      name: "The Hive",
      uids: [13041101..13041132, 13041201..13041230, 13041301..13041329]
    },
    {
      name: "unmapped",
      uids: [13041330..13041330]
    }
  ],
  attack_attributes: {
    physical_attacks: [
      {
        name: "Bite"
      },
      {
        name: "Pincer (attack)"
      },
      {
        name: "Bladed forelegs",
        as: (532..541)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Feint"
      },
      {
        name: "Headbutt"
      },
      {
        name: "Crowd Press"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [
      {
        name: "Kiramon lunge"
      },
      {
        name: "Durable Carapace"
      },
      {
        name: "Chitin Disarm"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: nil,
    ranged: (225..474),
    bolt: (225..474),
    udf: (669..1030),
    bar_td: nil,
    cle_td: (402..408),
    emp_td: 420,
    pal_td: (360..369),
    ran_td: (366..375),
    sor_td: nil,
    wiz_td: nil,
    mje_td: (448..454),
    mne_td: (448..454),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: [
      "Brace-like effect",
      "Durable carapace"
    ]
  },
  special_other: nil,
  abilities: [],
  alchemy: [],
  abilities_misc: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: false,
    skin: "some glossy kiramon chitin",
    other: nil,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    description: [
      "The myrmidon's chitin is a cold and lustrous black, infused with an oil slick of darkly rainbowed colors that are almost hypnotically beautiful to behold. Clusters of barbed spines protrude from the upper segments of his spindly arms, each of which ends in a sharp scythe-like claw. Above a set of oversized, prehensile mandibles, the kiramon myrmidon's orb-shaped eyes are a sullen red and are faceted like pristine rubies. They are possessed of an intellect that is as vast as it is otherworldly."
    ],
    arrival: [],
    flee: [],
    death: [
      "A chitinous kiramon myrmidon collapses, {pronoun} forelegs spasming and twitching before {pronoun} at last surrenders to death."
    ],
    decay: [],
    search: [
      "A chitinous kiramon myrmidon's faceted eyes reflect nothing but empty shadows as {pronoun} twitches {pronoun} head to look around, hesitantly, as if {pronoun} has missed something."
    ],
    spell_prep: [
      "A chitinous kiramon myrmidon hisses and clicks, cocking {pronoun} head curiously as if not entirely comprehending your death."
    ],
    stun_break: [
      "A chitinous kiramon myrmidon spasms as {pronoun} tries to regain control of {pronoun} scattered senses.",
      "A chitinous kiramon myrmidon shakes off {pronoun} unconscious state."
    ],
    attacks: {
      attack: [
        "A chitinous kiramon myrmidon strikes out at you with all of {pronoun} might!",
        "Bringing {pronoun} forelegs together, a chitinous kiramon myrmidon attempts to pincer you!",
        "Surging forward powerfully, a chitinous kiramon myrmidon slashes at you with {pronoun} bladed forelegs!",
        "A chitinous kiramon myrmidon slams {pronoun} head into you!",
        "A chitinous kiramon myrmidon vomits a bit of brackish goo onto a crack in {pronoun} chitin, using one foreleg to massage the glutinous muck over the breach."
      ],
      bite: [
        "A chitinous kiramon myrmidon snaps {pronoun} armored head {direction}, a fractured mirror of the surroundings visible in {pronoun} compound eyes."
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
