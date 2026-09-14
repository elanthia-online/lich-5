{
  name: "Quivering sanguine ooze",
  noun: "ooze",
  url: "https://gswiki.play.net/Quivering_sanguine_ooze",
  picture: "",
  level: 107,
  family: "Ooze",
  type: "Globoid",
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
  areas: [
    {
      name: "Hinterwilds",
      uids: [7503401..7503421, 7503467..7503498]
    }
  ],
  bcs: true,
  max_hp: 600,
  speed: 12,
  height: 12,
  size: "huge",
  attack_attributes: {
    physical_attacks: [
      {
        name: "Huge black alloy greatsword",
        as: (596..679)
      },
      {
        name: "Yellowed brittle bone cudgel",
        as: 583
      },
      {
        name: "Fists",
        as: (558..559)
      },
      {
        name: "Glistening tendril",
        as: (595..606)
      },
      {
        name: "Talons",
        as: 600
      },
      {
        name: "Crush",
        as: 614
      },
      {
        name: "Shark-like teeth",
        as: 505
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Yellowed brittle bone cudgel",
        cs: 460
      },
      {
        name: "Lash",
        cs: 389
      }
    ],
    offensive_spells: [],
    maneuvers: [],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (464..847),
    ranged: (365..631),
    bolt: (365..631),
    udf: (568..899),
    bar_td: nil,
    cle_td: 447,
    emp_td: 481,
    pal_td: (420..423),
    ran_td: (424..430),
    sor_td: nil,
    wiz_td: nil,
    mje_td: 499,
    mne_td: (451..499),
    mjs_td: nil,
    mns_td: nil,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  equipment: [],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: nil,
    other: [
      "ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    flee: [
      "A quivering sanguine ooze just went through a pair of colossal red stone pillars.",
      "A quivering sanguine ooze just went through a break in the trees.",
      "A quivering sanguine ooze just went through a crumbling red stone maw.",
      "A quivering sanguine ooze just went through a ragged acid-pocked gash.",
      "A quivering sanguine ooze just went through a pocked red stone arch."
    ],
    arrival: [
      "A quivering sanguine ooze just came through a break in the trees.",
      "A quivering sanguine ooze just came through a pocked red stone arch.",
      "A quivering sanguine ooze just came through a ragged acid-pocked gash.",
      "A quivering sanguine ooze glides in, leaving a slick trail behind {pronoun}."
    ],
    decay: [
      "A quivering sanguine ooze rapidly coagulates, the air sucking the moisture from {pronoun} shape. What remains of the ooze flakes into a pile of reddish-black grit."
    ],
    attacks: {
      attack: [
        "A quivering sanguine ooze tries to strangle you with a glistening tendril!",
        "A quivering sanguine ooze manifests a thick pseudopod and brings {pronoun} smashing down at you!"
      ]
    },
    info: {
      general: [
        "* Oozes are essentially noncorporeal, uncrittable, unstunnable damage sponges that often divide themselves into oozelings upon getting hit, where each oozeling has a fraction of the original ooze's health but otherwise has similar combat abilities and stats on all fronts. If left unchecked long enough, the oozelings' health will grow. Since oozes reduce their own health by splitting and since they split when they're attacked, using even weak AoE attacks can clear rooms more quickly than using powerful single-target attacks. Clash, Cyclone, Divine Incarnation (1650) Onslaught, Divine Wrath (335), Judgment (1630), Nature's Fury (635), Pulverize, Song of Sonic Disruption (1030), Volley (with a short bow or hand crossbow only to keep RT manageable), Whirling Blade, and Whirlwind are all good. In particular, Divine Wrath, Song of Sonic Disruption, and Volley stand out due to respectively multiple rounds of damage, low mana cost (upon renewal), and low stamina cost mixed with multiple rounds of damage. All three of those options can lead to rooms going from one ooze to ten in no time, then down to zero also in no time, as oozes divide constantly.\n* If absorbed by an ooze, an adventurer can attack its organ until it spits them out.\n** Military pick worked, dagger & spear did not.\n* Culling bounties for oozes go quickly since oozelings count."
      ],
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
  }
}
