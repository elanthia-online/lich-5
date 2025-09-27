{
  name: "bloody halfling cannibal",
  url: "https://gswiki.play.net/Bloody_halfling_cannibal",
  picture: "",
  level: 101,
  family: "humanoid",
  type: "biped",
  undead: "",
  otherclass: [],
  areas: [
    "hinterwilds"
  ],
  bcs: true,
  hitpoints: 300,
  speed: "",
  height: 3,
  size: "small",
  attack_attributes: {
    physical_attacks: [
      {
        name: "bite",
        as: 474
      },
      {
        name: "grimy little fists",
        as: (464..544)
      },
      {
        name: "hurtle",
        as: (327..564)
      },
      {
        name: "wiry arms",
        as: (464..544)
      }
    ],
    bolt_spells: [],
    warding_spells: [],
    offensive_spells: [],
    maneuvers: [
      {
        name: "cannibalize"
      }
    ],
    special_abilities: [
      {
        name: "hunger",
        note: "+80 AS"
      },
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "12",
    immunities: [],
    melee: (379..383),
    ranged: (353..366),
    bolt: (353..366),
    udf: (586..805),
    bar_td: (364..379),
    cle_td: nil,
    emp_td: nil,
    pal_td: nil,
    ran_td: (335..350),
    sor_td: nil,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 428,
    mjs_td: nil,
    mns_td: 381,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [
      {
        name: "unstun",
        note: "able to break stuns"
      },
      {
        name: "vanish",
        note: "able to evade an attack by hiding in the shadows"
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
    other: "gigas artifact",
    blunt_required: false
  },
  messaging: {
    description: "A skim of dark, congealing blood slicks the features of the raw-boned halfling.  {pronoun} eyes are black as burnt coals and feverish with single-minded hunger, a hunger that has burnt away every last shred of fat from {pronoun} body and left behind only knotted sinew.  The cannibal's teeth are sharpened to jagged points, and from between them darts a tiny pink tongue that is constantly tasting the air.  {pronoun} wears tattered, weather-eaten remains of furs and homespun fabric.  They, too, are soaked red with blood.",
    arrival: [
      "Accompanied by the fetid stench of old meat, a bloody halfling cannibal races into the area with a froth of bloody saliva on {pronoun} lips.",
      "You hear soft footfalls."
    ],
    flee: [
      "Licking {pronoun} lips ravenously, a bloody halfling cannibal creeps {direction}.",
      "You hear soft footfalls."
    ],
    death: "A monstrous, too-wide smile spreads across the cannibal's face as {prooun} collapses to the ground, dead.",
    decay: "A bloody halfling cannibal's body rots away, leaving only a small stain on the ground.",
    search: [
      "A bloody halfling cannibal sniffs at the air, {pronoun} eyes glinting as {pronoun} searches the shadows.",
      "a bloody halfling cannibal's eyes dart around, suspicion warring with hunger in {pronoun} beady eyes."
    ],
    hide: "A bloody halfling cannibal darts into the shadows.",
    vanish: "As you move to attack a bloody halfling cannibal, the cannibal shrinks away from you, baring sharpened teeth as {pronoun} darts into the shadows!",
    hunger: "A bloody halfling cannibal's eyes grow bloodshot with ravening hunger!",
    unstun: "A bloody halfling cannibal gurgles out an animalistic shriek of rage, {pronoun} eyes filling with bloody blackness as {pronoun} surges back into action!",
    cannibalize: "A bloody halfling cannibal falls into a lopsided crouch.  The muscles of {pronoun} hindquarters tense as {pronoun} springs toward you, sharpened teeth gnashing.",
    wiry_arms: [
      "A bloody halfling cannibal throws her wiry arms around you, fueled by panicked hunger!",
      "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and throws {pronoun} wiry arms around you, fueled by panicked hunger!"
    ],
    hurtle: [
      "A bloody halfling cannibal hurtles at you, swinging wildly with a twisted obsidian dagger!",
      "With an ululating shriek, a bloody halfling cannibal leaps from the shadows and hurtles at you, swinging wildly with a twisted obsidian dagger!"
    ],
    bite: "A bloody halfling cannibal bares {pronoun} sharpened teeth as {pronoun} tries to bite into you!",
    grimy_little_fists: "A bloody halfling cannibal hammers blindly at you with grimy little fists!",
    general_advice: "* Despite being the lowest level creature in the [[Hinterwilds]], cannibals can't be underestimated or ignored, especially if the Boreal Forest has started filling up. Cannibals' namesake biting maneuver can be lethal if its [[standard maneuver roll]] gets a significant bonus from other creatures in the area stunning or otherwise disabling a character. Cannibals also take advantage of stealth, which means they can get stance pushdown from [[ambush]] mechanics in situations where you might never have seen them coming. As such, even in cases where relatively low-mana-cost AoE spells like [[Censure (316)]], [[Elemental Wave (410)]], or [[Grasp of the Grave (709)]] might seem unnecessary for the number of visible creatures, sometimes they can still be helpful in revealing the invisible threat of cannibals.",

  }
}
