{
  name: "stunted halfling bloodspeaker",
  url: "https://gswiki.play.net/Stunted_halfling_bloodspeaker",
  picture: "",
  level: 103,
  family: "humanoid",
  type: "biped",
  undead: "",
  otherclass: [],
  areas: [
    "hinterwilds"
  ],
  bcs: true,
  hitpoints: 367,
  speed: "",
  height: 3,
  size: "small",
  attack_attributes: {
    physical_attacks: [
      {
        name: "attack",
        as: (420..550)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "blood burst (701)",
        cs: (455..473)
      },
      {
        name: "bone shatter (1106)",
        cs: (439..454)
      },
      {
        name: "corrupt essence (703)",
        cs: (455..473)
      },
      {
        name: "limb disruption (708)",
        cs: (455..473)
      },
      {
        name: "wither (1115)",
        cs: (439..454)
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "2",
    immunities: [],
    melee: (467..502),
    ranged: (521..530),
    bolt: (451..541),
    udf: (542..568),
    bar_td: 470,
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (400..412),
    sor_td: 482,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 537,
    mjs_td: nil,
    mns_td: (450..461),
    mnm_td: nil,
    defensive_spells: [
      {
        name: "prayer (313)"
      },
      {
        name: "foresight (1204)"
      },
      {
        name: "mindward (1208)"
      }
    ],
    defensive_abilities: [
      {
        name: "health regen",
        note: "similar to trolls blood or regeneration?"
      },
      {
        name: "unstun",
        note: "able to break stuns"
      }
    ],
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  treasure: {
    coins: true,
    magic_items: nil,
    gems: true,
    boxes: true,
    skin: false,
    other: ["herbs", "gigas fragments"],
    requires_blunt: false
  },
  messaging: {
    description: "Small even for a halfling, the bloodspeaker is twisted of limb and stunted of form.  Bulging eyes the color of dried blood peer out from a face like molten wax.  The ritualistic burn scars marring {pronoun} flesh look painful beyond the most grotesque of imaginings.  The bloodspeaker wears heavy robes of red velvet that do little to conceal the broken-puppet jangle of {pronoun} misshapen body beneath them.  {pronoun} tongue is bisected and lolls forth from a mouth that looks like a wet gash in {pronoun} obscene face.",
    arrival: "A stunted halfling bloodspeaker hurries in, ebon eyes darting about in paranoia.",
    flee: "Ebon eyes darting about in paranoia, a stunted halfling bloodspeaker hurries {direction}.",
    spell_prep: "A stunted halfling bloodspeaker utters a garbled, sibilant phrase as globules of crimson light spin around {pronoun} gnarled hands.",
    death: "A stunted halfling bloodspeaker's eyes bulge as {pronoun} stares toward the heavens, mouthing a gurgling prayer as {pronoun} succumbs to death.",
    decay: "A stunted halfling bloodspeaker's body collapses in upon itself as if everything solid within has turned to liquid, the sanguine remains oozing out of the remaining folds of skin.",
    search: [
      "A stunted halfling bloodspeaker licks her lips as she looks around, as if certain that she has missed something.",
      "a stunted halfling bloodspeaker's sniffs the air, bulging eyes darting about wildly"
    ],

    unstun: "Rivulets of swirling incarnadine energy envelop a stunted halfling bloodspeaker's scarred flesh, allowing {pronoun} to move freely once more.",
    stand: "A stunted halfling bloodspeaker struggles, grunting and cursing as {pronoun} rises to {pronoun} feet.",
    health_regen: [
      "A stunted halfling bloodspeaker raises {pronoun} malformed fingers overhead, contorting them into jarring patterns as globules of carmine radiance pirouette through the air around {pronoun}. The spinning beads of radiance gather into a dripping sanguine orb that hovers in the air nearby, pulsing with otherworldly light.",
      "Eldritch radiance from a swirling sanguine orb bathes a stunted halfling bloodspeaker, causing {pronoun} wounds to sluggishly tug themselves closed in the sanguine light."
    ],
    attack: "With incongruous alacrity, a stunted halfling bloodspeaker swings {weapon} at you!",
    bone_shatter: "A stunted halfling bloodspeaker concentrates intently on you, and a pulse of pearlescent energy ripples toward you!",
    wither: "The force of a stunted halfling bloodspeaker's power warps the air as it surges toward you!",

    general_advice: "* Warding casters will have more success against this creature with a high [[TD]] if they cast dispelling magic upon it first.\n* [[Standard_maneuver_roll|SMR]]-based attacks like [[Condemn (309)]], [[Earthen Fury (917)]], and [[Spike Thorn (616)]] frequently tear through bloodspeakers. [[Animal Companion (630)|Animal companions]] can also do significant damage.\n* [[Silenced|Silencing]] tactics like [[Cutthroat]] and [[Sucker Punch]], or the similar [[Corrupt Essence (703)]], will halt their threatening [[Wither (1115)]] spell. ([[Silence (210)]] itself is unlikely to hit barring an unusual build heavily focused on [[Major Spiritual]] ranks.)",
  }
}

=begin
description, arrival, flee, death, decay, search, spell_prep, creature specific
# blood burst
A stunted halfling bloodspeaker points a blunt, swollen finger at you!
  CS: +455 - TD: +410 + CvA: +5 + d94: +91 - -5 == +146
  Warding failed!
Blood sprays from your neck in a crimson arc!
   ... 10 points of damage!
Attenuated droplets of Nisugi's blood are drawn into the sanguine lattice encircling a stunted halfling bloodspeaker.

# limb disruption
A stunted halfling bloodspeaker points a blunt, swollen finger at you!
  CS: +473 - TD: +410 + CvA: +5 + d91: +48 - -5 == +121
  Warding failed!
Your left leg twists painfully but does not break.
You are stunned 1 round!

# corrupt essence
A stunted halfling bloodspeaker points a blunt, swollen finger at you!
  CS: +473 - TD: +393 + CvA: +5 + d80: +16 - -5 == +106
  Warding failed!
You feel weakened as a blood red haze forms around you.

The veins of a stunted halfling bloodspeaker's blood shield shrivel and dry, darkening brown and flaking away into windblown dust.

=end
