{
  name: "tattooed gigas berserker",
  noun: "berserker",
  url: "https://gswiki.play.net/Tattooed_gigas_berserker",
  picture: "",
  level: 103,
  family: "gigas",
  type: "biped",
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
  max_hp: 900,
  speed: 8,
  height: 30,
  size: "huge",
  attack_attributes: {
    physical_attacks: [
      {
        name: "hatchet",
        as: (531..563)
      },
      {
        name: "Charge",
        as: (529..535)
      },
      {
        name: "Enormous tusks",
        as: (529..539)
      },
      {
        name: "Golden targe",
        as: 556
      },
      {
        name: "Immense fel-hafted handaxe",
        as: (520..545)
      },
      {
        name: "Lunge",
        as: (520..545)
      },
      {
        name: "Crush",
        as: 500
      },
      {
        name: "Tusks",
        as: 519
      }
    ],
    bolt_spells: [],
    warding_spells: [
      {
        name: "Shield Bash",
        cs: 437
      }
    ],
    offensive_spells: [],
    maneuvers: [
      {
        name: "Charge"
      },
      {
        name: "Pounce"
      },
      {
        name: "Shield Bash"
      }
    ],
    special_abilities: [],
    special_notes: []
  },
  defense_attributes: {
    asg: "10",
    immunities: [],
    melee: (243..762),
    ranged: (304..615),
    bolt: (304..615),
    udf: (466..913),
    bar_td: 401,
    cle_td: (406..476),
    emp_td: (406..418),
    pal_td: (366..375),
    ran_td: (333..442),
    sor_td: (438..448),
    wiz_td: nil,
    mje_td: (461..471),
    mne_td: (461..471),
    mjs_td: (360..418),
    mns_td: (360..418),
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "",
  abilities: [
    {
      id: :frenzy,
      name: "Frenzy",
      type: :buff,
      target: :self,
      messaging: [
        "A tattooed gigas berserker flies into a wild rage, animalistic fury washing over {pronoun} features!",
        "A tattooed gigas berserker falls deeper into bloodlust, gnashing {pronoun} teeth and clenching {pronoun} immense muscles!"
      ]
    }
  ],
  alchemy: [],
  equipment: [
    "a suit of tanned boarhide adorned with crudely etched bronze disks",
    "an immense fel-hafted handaxe"
  ],
  treasure: {
    coins: true,
    magic_items: true,
    gems: true,
    boxes: true,
    skin: false,
    other: [
      "gigas fragments",
      "ayanad crystal",
      "n'ayanad crystal",
      "petrified mammoth tusk"
    ],
    blunt_required: false,
    armaments: [
      "drake greatsword",
      "drake greataxe"
    ],
    transmogs: nil
  },
  messaging: {
    flee: [
      "A tattooed gigas berserker just went into a thatched timber smithy.",
      "A tattooed gigas berserker just went into a huge hut.",
      "A tattooed gigas berserker charges {direction}, driven by battle-lust.",
      "A tattooed gigas berserker just went into a huge hoarbeam longhouse.",
      "A tattooed gigas berserker just went into a long timber hall.",
      "A tattooed gigas berserker rides {target} out, swaying with every heavy footfall."
    ],
    description: "A tattooed gigas berserker is a hulking brute of a gigas, standing more than four times the height of a man and with the immense muscle mass to match.  His vast biceps are ringed with intricate tattoos in auroral colors: glacial blues and flashfire greens that are bright enough to have been stolen from cut jewels.  The rest of him is unlovely, from his matted beard to the look of murder in his bulging eyes.",
    arrival: [
      "Preceded by a mournful dirge, a grim gigas skald stalks in, {pronoun} song accompanied by the clacking of the crude jeweled beads adorning the ceremonial garb that {pronoun} wears.",
      "A tattooed gigas berserker charges in, madness twisting {pronoun} features.",
      "A tattooed gigas berserker barrels in, bellowing a mad battlecry that shakes the ground with {pronoun} intensity!",
      "A tattooed gigas berserker rides {target} in, swaying with every heavy footfall.",
      "A tattooed gigas berserker rides {target} in, {target} limping with every great step.",
      "A tattooed gigas berserker just came through a breached red stone wall."
    ],
    death: [
      "A tattooed gigas berserker's fists tense with impotent rage as {pronoun} surrenders to death.",
      "A grim gigas skald raises a hand as if to grasp for support as {pronoun} collapses, life going out of {pronoun} form.",
      "The tattooed gigas berserker slumps to the ground.",
      "A tattooed gigas berserker's eyes roll up into {pronoun} head as {pronoun} body goes limp on the ground."
    ],
    decay: [
      "Creeping decay races across a tattooed gigas berserker's prone form, swiftly consuming the body despite its colossal size."
    ],
    search: [
      "A tattooed gigas berserker raises his great head, bulging eyes searching the shadows.",
      "A tattooed gigas berserker's brow knits sneers as his eyes fruitlessly search the shadows.",
      "A tattooed gigas berserker looks around blissfully, a tranquil smile on {pronoun} face."
    ],


    stand: [
      "A tattooed gigas berserker rolls to {pronoun} feet, with an eerily silent roar!"
    ],
    spell_prep: [
      "A tattooed gigas berserker's eyes begin to glow purple."
    ],
    stun_break: [
      "A tattooed gigas berserker's eyes open wide, crimson with fury, as {pronoun} breaks free from {pronoun} pacified state!"
    ],
    ambient: [
      "A tattooed gigas berserker totters around, looking as if {pronoun} is about to topple!"
    ],
    attacks: {
      attack: [
        "Froth bubbling on {pronoun} lips, a tattooed gigas berserker swings {weapon} at you in a murderous arc!",
        "Looming over you, a tattooed gigas berserker tries to reach down and crush you in a massive fist!",
        "A heavily armored battle mastodon tries to spear you with {pronoun} enormous tusks!",
        "Froth bubbling on {pronoun} lips, a {pronoun} swings {weapon} at you in a murderous arc!",
        "Murder in {pronoun} eyes, an immense gold-bristled hinterboar tries to gore you with {pronoun} tusks!",
        "A tattooed gigas berserker leaps from the back of {target} as {target} topples, narrowly avoiding being pinned beneath {target} mount!",
        "A tattooed gigas berserker raises a huge foot and tries to squash you like a bug!",
        "Stooping down from his vast height, a tattooed gigas berserker reaches toward you with a gigantic fist!  You scurry out of the way of the huge fingers, heart pounding in your chest!",
        "A tattooed gigas berserker barrels in, bellowing a mad battlecry that shakes the ground with {pronoun} intensity!",
        "A tattooed gigas berserker leaps to {pronoun} feet, landing with a frothing snarl.",
        "The tattooed gigas berserker slams into {target}, who is sent careening headlong into a nearby group of combatants as {pronoun} falls to the ground!",
        "The tattooed gigas berserker slams into you, and you are sent careening headlong into a nearby group of combatants as you fall to the ground!",
        "A tattooed gigas berserker strikes out at {target} with all of {pronoun} might!",
        "A tattooed gigas berserker charges out, driven by battle-lust.",
        "The tattooed gigas berserker slams into you, and you are sent careening into {target} as you fall to the ground!",
        "A tattooed gigas berserker jabs a colossal finger into the shadows, revealing {target}, who was hidden!",
        "The tattooed gigas berserker slams into {target}, who is sent careening to the ground!",
        "A tattooed gigas berserker jabs a colossal finger into the shadows, revealing you in your hiding place!"
      ]
    },
    info: {
      general: [
        "* Berserkers are square creatures in fairly light armor, so players of semis and pures can take advantage of low TD and CvA by casting CS-based offensive spells."
      ],
      class_tips: {
        cleric: [],
        paladin: [],
        ranger: [],
        bard: [
          "* By destroying berserkers' weapons, Vibration Chant (1002) stops many of the most threatening things they can do and sometimes kills them outright."
        ],
        wizard: [
          "* Berserkers can be targeted with Mana Leech (516)."
        ],
        empath: [],
        rogue: [],
        warrior: [],
        sorcerer: []
      },
      miscellany: []
    },
    frenzy: "A tattooed gigas berserker flies into a wild rage, animalistic fury washing over {pronoun} features!"
  }
}

=begin

  A tattooed gigas berserker glares at you and lets out a nerve-shattering bellow!
  [SSR result: 101 (Open d100: 53)]
  You maintain your resolve, ignoring the unnerving cry!


  In a breathtaking display of agility and combat mastery, a tattooed gigas berserker whirls in a fury of unrelenting strikes and ripostes!
  Froth bubbling on his lips, a tattooed gigas berserker swings an immense fel-hafted handaxe at you in a murderous arc!
  You barely dodge the attack!
  The ethereal necrotic film covering a tattooed gigas berserker's fel-hafted handaxe shrivels away.

  In a breathtaking display of agility and combat mastery, a tattooed gigas berserker whirls in a fury of unrelenting strikes and ripostes!
  Froth bubbling on his lips, a tattooed gigas berserker swings an immense fel-hafted handaxe at you in a murderous arc!
    AS: +516 vs DS: +896 with AvD: +30 + d100 roll: +97 = -253
    A clean miss.

  In a display of martial precision, a brawny gigas shield-maiden thrusts with a gold-tipped heavy spear at you!
  A blackened mithril greathelm partially deflects the onslaught of the puncture attack.
    AS: +566 vs DS: +403 with AvD: +28 + d100 roll: +48 = +239
    ... and hits for 60 points of damage!
    Pierced through neck, a fine shot!
    You are stunned for 4 rounds!


  [SMR result: 118 (Open d100: 93, Bonus: 29)]
  Stooping down from his vast height, a tattooed gigas berserker reaches toward you with a gigantic fist!  Although you struggle to get away, his massive fingers snatch at you!
    ... 5 points of damage!
    Slight leg hold.

  In a breathtaking display of agility and combat mastery, a tattooed gigas berserker whirls in a fury of unrelenting strikes and ripostes!
  Froth bubbling on her lips, a tattooed gigas berserker swings an immense fel-hafted handaxe at you in a murderous arc!
    AS: +517 vs DS: +838 with AvD: +30 + d100 roll: +47 = -244
    A clean miss.


  A tattooed gigas berserker hangs back for a moment and concentrates intently on you, before unleashing an attack on the magical wards surrounding you!
  [SMR result: 96 (Open d100: 80)]
  A tattooed gigas berserker fails to connect solidly with any magical ward.

  In a breathtaking display of agility and combat mastery, a tattooed gigas berserker whirls in a fury of unrelenting strikes and ripostes!
  Froth bubbling on his lips, a tattooed gigas berserker swings an immense fel-hafted handaxe at you in a murderous arc!
    AS: +527 vs DS: +753 with AvD: +30 + d100 roll: +21 = -175
    A clean miss.

  [SMR result: 167 (Open d100: 143, Bonus: 21)]
  Stooping down from his vast height, a tattooed gigas berserker reaches toward you with a gigantic fist!  Massive fingers close around your midsection as the berserker tries to squeeze the life out of you!
    ... 20 points of damage!
    Hard shove to the midriff staggers you.
    You are stunned for 3 rounds!
  The berserker lifts you into the air, trapping you in his huge fist!

  [SMR result: 167 (Open d100: 143, Bonus: 21)]
  Stooping down from his vast height, a tattooed gigas berserker reaches toward you with a gigantic fist!  Massive fingers close around your midsection as the berserker tries to squeeze the life out of you!
    ... 20 points of damage!
    Hard shove to the midriff staggers you.
    You are stunned for 3 rounds!
  The berserker lifts you into the air, trapping you in his huge fist!

  [SMR result: 143 (Open d100: 16, Bonus: 113)]
  A tattooed gigas berserker grabs your hair and lifts you.  With a malevolent grin on his face, he winds up and hurls you into the air, sending you flying through a rune-carved white granite arch.
  [Ojandhaart, Approach - 29900] (u7503118)
  The dirt roadway proceeds beneath a monumental arch of white granite, the surface of which is roughly carved with an arcing spray of runes.  Beyond, smoke rises from the high roofs of buildings made from raw timber and rough-hewn stone.  All of the buildings are several times the height of a tall man.
  Obvious paths: west
  [claim.room] "claimed 7503118"
  You hit the ground hard at the end of your catastrophic descent!
    ... 10 points of damage!
    Light strike to your chest.

  In a breathtaking display of agility and combat mastery, a tattooed gigas berserker whirls in a fury of unrelenting strikes and ripostes!
  Froth bubbling on his lips, a tattooed gigas berserker swings an immense fel-hafted handaxe at you in a murderous arc!
  Rolling hurriedly, you dodge the attack!

  A tattooed gigas berserker gets a running start and then acrobatically leaps up onto the back of a heavily armored battle mastodon, mounting it!

  A tattooed gigas berserker rides a heavily armored battle mastodon southeast, the mastodon limping with every great step.

=end
