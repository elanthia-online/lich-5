{
  name: "Roiling crimson angargeist",
  noun: "angargeist",
  url: "https://gswiki.play.net/Roiling_crimson_angargeist",
  picture: "",
  level: 110,
  family: "",
  type: "",
  undead: true,
  blood: nil,
  bones: nil,
  limbs: true,
  witherable: true,
  muggable: true,
  sleepable: false,
  boss: false,
  boss_type: nil,
  otherclass: ["Non Corporeal undead"],
  areas: [
    {
      name: "Hinterwilds",
      uids: [7503422..7503466]
    }
  ],
  bcs: true,
  max_hp: 600,
  speed: nil,
  height: 13,
  size: "large",
  attack_attributes: {
    physical_attacks: [
      {
        name: "Dagger-sharp beak",
        as: (610..616)
      },
      {
        name: "Huge black alloy greatsword",
        as: (589..667)
      },
      {
        name: "Shining metallic spear",
        as: (616..654)
      },
      {
        name: "Slash",
        as: (574..583)
      },
      {
        name: "Talons",
        as: (600..610)
      },
      {
        name: "?: Blow raises a welt",
        as: 582
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: nil,
    immunities: [],
    melee: (530..739),
    ranged: (452..600),
    bolt: (452..600),
    udf: (490..652),
    bar_td: nil,
    cle_td: (486..492),
    emp_td: 477,
    pal_td: (438..447),
    ran_td: 441,
    sor_td: 504,
    wiz_td: nil,
    mje_td: 541,
    mne_td: nil,
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
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: nil,
    transmogs: nil
  },
  messaging: {
    decay: [
      "A roiling crimson angargeist dissolves into a pool of ectoplasm that roils over you, snapping with toothless mouths and grasping with desperate fingers before reforming on the other side."
    ],
    flee: [
      "A roiling crimson angargeist flows {direction}, {pronoun} amorphous bulk sprouting appendages and hideous features at random.",
      "A roiling crimson angargeist just went through a crumbling red stone maw.",
      "A roiling crimson angargeist just went through a breached red stone wall.",
      "A roiling crimson angargeist just went through a pocked red stone arch.",
      "A roiling crimson angargeist just went through a pair of colossal red stone pillars.",
      "A roiling crimson angargeist sends questing tentacles of ectoplasm toward the shadows, but {pronoun} find nothing and retreat, quivering anxiously."
    ],
    arrival: [
      "A roiling crimson angargeist just came through a pocked red stone arch.",
      "A roiling crimson angargeist just came through a breached red stone wall."
    ],
    description: "Swirling ectoplasm, crimson and black and lit from within by crackles of sickly yellow energy, takes on a rough humanoid shape, but the angargeist is clearly nothing alive.  Where a face ought to be is a molten ruin, lopsided eyes of unholy flame sparking in its ill-made sockets.  Immaterial and dripping essence, the arms and legs are uneven, both ending in straining talons.  The angargeist's form bubbles and simmers in places like fury lent form.",
    sympathy: true,
    ambient: [
      "A roiling crimson angargeist lights from within, energy crackling within {pronoun} chaotic core.",
      "A roiling crimson angargeist swarms low over the ground as if questing for something unseen."
    ],
    attacks: {
      bolt: [
        "A roiling crimson angargeist hurls a ball of greenish-black flame at {target}!"
      ],
      attack: [
        "A roiling crimson angargeist sprouts twitching, misshapen hands that gesture at you!",
        "Misshapen arms erupt from a roiling crimson angargeist to flail at you!",
        "Shrieking rage from dozens of phantasmal throats, a roiling crimson angargeist sprouts dripping claws that slash at you!"
      ],
      vortex_smr: [
        "The shadows bubble and seethe as a roiling crimson angargeist rematerializes, swirling together into a vortex of vile energies!\nCrackling torrents of spectral energy erupt from the angargeist as it reforms, warping the air as they ripple outward!"
      ]
    },
    triggers: {
      fade: [
        "Angargeist fade similar to Banshee and reappear randomly."
      ]
    },
  }
}
