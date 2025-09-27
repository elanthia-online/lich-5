{
  name: "brawny gigas shield-maiden",
  url: "https://gswiki.play.net/Brawny_gigas_shield-maiden",
  picture: "",
  level: 106,
  family: "gigas",
  type: "biped",
  undead: "",
  otherclass: [],
  areas: [
    "hinterwilds"
  ],
  bcs: true,
  hitpoints: "",
  speed: "",
  height: 30,
  size: "huge",
  attack_attributes: {
    physical_attacks: [
      {
        name: "shield strike",
        as: (525..566)
      },
      {
        name: "spear",
        as: (525..566)
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "aura of the arkati (1614)",
        cs: (440..482)
      },
      {
        name: "judgment (1630)",
        cs: (443..482)
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "shield bash",
      },
      {
        name: "shield push"
      },
      {
        name: "shield trample"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "17",
    immunities: [],
    melee: (463..695),
    ranged: (383..548),
    bolt: nil,
    udf: nil,
    bar_td: (377..380),
    cle_td: nil,
    emp_td: 411,
    pal_td: nil,
    ran_td: (311..341),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 462,
    mjs_td: nil,
    mns_td: (396..408),
    mnm_td: nil,
    defensive_spells: [
      {
        name: "divine shield (1609)"
      },
      {
        name: "dauntless (1606)"
      }
    ],
    defensive_abilities: [
      {
        name: "damage resistance",
        note: "able to gain resistance to damage type attacked with"
      }
    ],
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  treasure: {
    coins: true,
    magic_items: "",
    gems: true,
    boxes: true,
    skin: false,
    other: "gigas fragment",
    blunt_required: false
  },
  messaging: {
    description: "Voluptuous and sturdy of build, the gigas shield-maiden has the musculature of a seasoned fighter and the cool gaze of a practiced tactician.  Towering at nearly thirty feet in height, the shield-maiden moves with a dangerous grace.  The armor {pronoun} wears is not ornate, but it shines like hammered gold and barely makes a sound as {pronoun} moves.",
    arrival: [
      "A brawny gigas shield-maiden marches in with the grace of a seasoned warrior.",
      "A brawny gigas shield-maiden marches into the area, grim purpose written across {pronoun} face.",
      "A brawny gigas shield-maiden rides a heavily armored battle mastodon in, swaying with every heavy footfall."
    ],
    flee: [
      "Warily scanning the area for threats, a brawny gigas shield-maiden marches {direction}.",
      "Keeping {pronoun} head held high in spite of {pronoun} wounds, a brawny gigas shield-maiden struggles {direction}.",
      "A brawny gigas shield-maiden just went into a thatched timber smithy.", # need to deal with portals
      "A brawny gigas shield-maiden rides a heavily armored battle mastodon {direction}, the mastodon limping with every great step."
    ],
    spell_prep: "A brawny gigas shield-maiden raises a fist to the heavens as {pronoun} eyes begin to glow like molten gold.",
    death: "A plaintive look passes across a brawny gigas shield-maiden's eyes like a fleeting shadow as {pronoun} goes still in death.",
    decay: "Rot consumes a brawny gigas shield-maiden's body, leaving little behind.",
    damage_resistance: "In response to the vibrations, a brawny gigas shield-maiden's skin seems to discolor and harden, lending the shield-maiden unnatural durability!",
    shield_bash: "A brawny gigas shield-maiden lunges forward at you with {pronoun} golden targe and attempts a shield bash!",
    shield_push: "A brawny gigas shield-maiden raises {pronoun} golden targe and attempts to push you away!",
    shield_strike: "A brawny gigas shield-maiden launches a quick bash with {pronoun} golden targe at you!",
    shield_trample: "A brawny gigas shield-maiden raises her golden targe and charges headlong towards you!",
    spear: "In a display of martial precision, a brawny gigas shield-maiden thrusts with a gold-tipped heavy spear at you!",

    general_advice: "* Shield-maidens are [[square]] creatures, so players of [[semi]]s and [[pure]]s can take advantage of their low [[TD]] by casting [[CS]]-based offensive spells.\n* Shield-maidens have a pretty high rate of blocking physical attacks with their shields when unhindered, so setup abilities like [[Sunder Shield]], [[Aura of the Arkati (1614)]], anything that inflicts [[Blinded]], anything that knocks prone, and so forth are recommended for primarily physical combatants. Alternatively, [[Brawling|unarmed combat]] can't be blocked.",
    bards: "* [[Vibration Chant (1002)]] works twice and will often leave them helpless or dead.",
    wizards: "* Shield-maidens can be targeted with [[Mana Leech (516)]].",

  }
}

=begin
# mount
A brawny gigas shield-maiden gets a running start and then acrobatically leaps up onto the back of a heavily armored battle mastodon, mounting it!

# reveal
A brawny gigas shield-maiden glowers disdainfully as she sweeps the surroundings with her gaze.
A brawny gigas shield-maiden points forcefully into the shadows, revealing you in your hiding place!

# damage resistance
In response to the vibrations, a brawny gigas shield-maiden's skin seems to discolor and harden, lending the shield-maiden unnatural durability!
A brawny gigas shield-maiden is unharmed by the impact!
A brawny gigas shield-maiden is unharmed by the impact!
A brawny gigas shield-maiden is unharmed by the impact!

=end
