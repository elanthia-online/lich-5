{
  name: "Grim gigas skald",
  noun: "skald",
  url: "https://gswiki.play.net/Grim_gigas_skald",
  picture: "",
  level: 105,
  family: "Gigas",
  type: "Biped",
  undead: false,
  blood: true,
  bones: nil,
  limbs: nil,
  witherable: true,
  sympathy: true,
  muggable: true,
  sleepable: nil,
  boss: false,
  boss_type: nil,
  otherclass: [],
  areas: [
    {
      name: "Hinterwilds",
      uids: [7503301..7503312, 7503321..7503332, 7503341..7503353, 7503361..7503366, 7503371..7503374, 7503381..7503384]
    }
  ],
  bcs: true,
  max_hp: 600,
  speed: 6,
  height: 28,
  size: "huge",
  attack_attributes: {
    physical_attacks: [
      {
        name: "Immense fel-hafted handaxe",
        as: (520..566)
      },
      {
        name: "Enormous tusks",
        as: (529..549)
      },
      {
        name: "Lunge",
        as: (520..560)
      },
      {
        name: "Golden targe",
        as: 581
      },
      {
        name: "Clawed fists",
        as: 560
      },
      {
        name: "Shark-like teeth",
        as: 450
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Stunning Shout (1008)",
        cs: (494..499)
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Pounce"
      },
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "6",
    immunities: [],
    melee: (423..775),
    ranged: (416..557),
    bolt: (416..557),
    udf: (479..731),
    bar_td: (430..443),
    cle_td: (452..498),
    emp_td: (449..464),
    pal_td: (413..423),
    ran_td: (381..414),
    sor_td: (486..496),
    wiz_td: nil,
    mje_td: (513..522),
    mne_td: (513..522),
    mjs_td: (381..461),
    mns_td: (381..461),
    mnm_td: nil,
    defensive_spells: [
      {
        name: "Warding Sphere (310)"
      },
      {
        name: "Lesser Shroud (120)"
      },
      {
        name: "Resist Elements (602)"
      }
    ],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  equipment: [
    "a ceremonial boarskin garment adorned with semiprecious gems",
    "an ornate ruic lyre with shimmering silver strings"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    spell_prep: [
      "A grim gigas skald concentrates intently on you, and a pulse of pearlescent energy ripples toward you!",
      "A grim gigas skald concentrates intently on {target}, and a pulse of pearlescent energy ripples toward {pronoun}!",
      "A grim gigas skald raises {pronoun} voice into a reverberating dirge, the surrounding shadows dancing in time with the tune.",
      "A grim gigas skald raises {pronoun} voice in a magical chant, sending a ripple of shimmering air toward you!"
    ],
    flee: [
      "A grim gigas skald just went into a huge hoarbeam longhouse.",
      "A grim gigas skald just went into a thatched timber smithy.",
      "A grim gigas skald just went into a long timber hall.",
      "A grim gigas skald just went into a huge hut.",
      "A grim gigas skald just went through a breached red stone wall."
    ],
    description: "A grim gigas skald is not especially tall for one of {pronoun} kind, but still stands just under two stories tall.  {Pronoun} has a raw-boned face and a grim gaze.  The robes he wears are of dusky golden boarskin and appear ceremonial, having been stitched with hundreds of beads made from semiprecious gems.  A grim gigas skald wears a tremendous drinking horn at {pronoun} belt.",
    arrival: [
      "Preceded by a mournful dirge, a grim gigas skald stalks in, {pronoun} song accompanied by the clacking of the crude jeweled beads adorning the ceremonial garb that {pronoun} wears.",
      "A grim gigas skald meanders in, dourly taking in the surroundings.",
      "A grim gigas skald arrives, stiffly favoring one leg.",
      "A grim gigas skald just arrived.",
      "A grim gigas skald just came through a breached red stone wall.",
      "A grim gigas skald just arrived, looking terrified.",
      "A grim gigas skald staggers in, looking to be on death's door."
    ],
    death: [
      "A grim gigas skald raises a hand as if to grasp for support as {pronoun} collapses, life going out of {pronoun} form.",
      "A grim gigas skald slumps, {pronoun} eyes dull and unfocused.",
      "A grim gigas skald's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground."
    ],
    decay: [
      "A grim gigas skald's corpse succumbs to rot, collapsing in upon {reflexive} until naught but dust remains."
    ],


    stand: [
      "A grim gigas skald flails on the ground, making the ground shudder, before managing to fight {pronoun} way into a standing position."
    ],
    attacks: {
      attack: [
        "A heavily armored battle mastodon raises {pronoun} trunk and slams it down toward you!",
        "A heavily armored battle mastodon tries to spear you with {pronoun} enormous tusks!",
        "Froth bubbling on {pronoun} lips, a tattooed gigas berserker swings {weapon} at you in a murderous arc!",
        "... and hits for 10 points of damage!"
      ],
      creature_spell: [
        "A grim gigas skald artfully plays her hoarbeam lyre, sending a ripple of shimmering air toward you!"
      ],
      shield_bash: [
        "A brawny gigas shield-maiden launches a quick bash with {pronoun} golden targe at you!"
      ]
    },
    info: {
      general: [
        "* Options like Hamstring or unarmed combat essentially get around DS, which is useful since skalds have pretty high DS even when forced into offensive stance and their unconventional lyre weapon can't be removed by typical tactics like Disarm Weapon or Vibration Chant (1002).\n* SMR-based offense like Condemn (309), Earthen Fury (917), and Spike Thorn (616) works well against skalds."
      ],
      class_tips: {
        cleric: [
          "* Since the strength of each damaging round of Condemn is based only on the initial roll, it can often be worthwhile to cast Condemn again before the first cast has finished if that first cast had a low enough endroll. This is especially true if the first cast isn't doing enough damage to keep them stunned, which is crucial since skalds' SMR attack can be lethal and their TD is sufficiently high that Soul Ward (319) isn't always reliable defense."
        ],
        paladin: [],
        ranger: [
          "* Spike Thorn is an excellent option, but if the ranger is relatively untrained to make use of it because he has few ranks of Ranger Base and/or Summoning lore, or simply if mana needs to be conserved, then animal companions can also do significant damage to or even kill skalds affected by Wild Entropy (603) or Moonbeam (611)."
        ],
        bard: [],
        wizard: [],
        empath: [],
        rogue: [],
        warrior: [],
        sorcerer: []
      },
      miscellany: []
    },
  }
}

=begin

A grim gigas skald raises her sonorous voice into a resounding cry that crashes like mad thunder through the area!
[SMR result: -6 (Open d100: -12, Bonus: 12)]
You manage to throw yourself free from the auditory assault!

Perfect harmonics collude to intensify a grim gigas skald's mastery of music!  A grim gigas skald artfully plays her ruic lyre, sending a ripple of shimmering air toward you!
  AS: +512 vs DS: +624 with AvD: +52 + d80 roll: +27 = -33
   A clean miss.

A grim gigas skald artfully plays her ruic lyre, sending a ripple of shimmering air toward you!
  AS: +412 vs DS: +594 with AvD: +52 + d79 roll: +56 = -74
   A clean miss.

A grim gigas skald artfully plays her ruic lyre, sending a ripple of shimmering air toward you!
You move at the last moment to evade the bolt!


A grim gigas skald flails on the ground, making the ground shudder, before managing to fight her way into a standing position.

One leg dragging behind her, a grim gigas skald staggers northwest.


=end
