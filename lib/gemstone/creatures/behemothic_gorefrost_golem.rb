{
  name: "Behemothic gorefrost golem",
  url: "https://gswiki.play.net/Behemothic_gorefrost_golem",
  picture: "",
  level: 104,
  family: "golem",
  type: "biped",
  undead: "",
  otherclass: [],
  areas: [
    "hinterwilds"
  ],
  bcs: true,
  hitpoints: 1000,
  speed: "",
  height: 40,
  size: "huge",
  attack_attributes: {
    physical_attacks: [
      {
        name: "closed fist",
        as: (480..500)
      },
      {
        name: "pound",
        as: 445
      },
      {
        name: "stomp",
        as: (495..505)
      }
    ],
    bolt_spells: [
      {
        name: "minor cold (1709)",
        as: 410
      }
    ],
    warding_spells: [
      {
        name: "cold snap (512)",
        cs: 444
      }
    ],
    offensive_spells: [
      {
        name: "major elemental wave (435)"
      }
    ],
    maneuvers: [
      {
        name: "haymaker"
      },
      {
        name: "headbutt"
      },
      {
        name: "heat leaching"
      },
      {
        name: "colossal fist"
      },
    ],
    special_abilities: [
      {
        name: "topple",
        type: "falls on you and ruins your day"
      }
    ],
    special_notes: []
  },
  defense_attributes: {
    asg: "20N",
    immunities: [],
    melee: 339,
    ranged: 317,
    bolt: 325,
    udf: 765,
    bar_td: 428,
    cle_td: nil,
    emp_td: 426,
    pal_td: nil,
    ran_td: 395,
    sor_td: 454,
    wiz_td: nil,
    mje_td: nil,
    mne_td: 457,
    mjs_td: nil,
    mns_td: 428,
    mnm_td: nil,
    defensive_spells: [],
    defensive_abilities: [],
    special_defenses: []
  },
  special_other: "",
  abilities: [],
  alchemy: [],
  treasure: {
    coins: true,
    magic_items: "",
    gems: true,
    boxes: true,
    skin: "None",
    other: "gigas artifact",
    blunt_required: false
  },
  messaging: {
    description: "The golem stands taller than a two-story building, a crude and blocky humanoid shape of ice that glows with an unsavory sanguine aura.  Clouds of frozen blood and bits of viscera are trapped in its frosty depths.  All are lifeless and still save for a single preserved organ at the golem's core: a humanoid heart.  The heart is shrouded in a swirl of slushy red fluid and, impossibly, it pulses with a sluggish, uneven beat, giving off coruscations of sanguine light.",
    arrival: [
      "The ground shudders as a behemothic gorefrost golem stomps in.",
      "The frozen earth underfoot shifts precipitously as an arm of blood-flecked ice erupts upward, followed by the towering form of a behemothic gorefrost golem.  The golem straightens its massive bulk with a sound like shattering glass."
    ],
    flee: [
      "A behemothic gorefrost golem stomps {direction}, shedding bits of broken ice and detritus.",
      "The ground shudders as a behemothic gorefrost golem stomps {direction}.",
    ],
    spell_prep: "A behemothic gorefrost golem glows with shimmering incarnadine light that suffuses its monstrous form with power.",
    death: "A rush of silent thunder explodes outward from the golem as the power animating it disperses.",
    decay: "Cracks spread over the surface of a behemothic gorefrost golem.  With a ringing sound like struck crystal, the golem shatters into shards of inert ice.",
    search: [
      "A behemothic gorefrost golem hesitates for a moment, as if uncertain.",
      "Corruscating light flares where a behemothic gorefrost golem's eyes ought to be as it searches the shadows."
    ],
    heat_leaching: "Hungering cold tears at your flesh, viciously leaching the heat from your body!",
    colossal_fist: "A behemothic gorefrost golem raises a colossal fist of enchanted ice overhead and brings it crashing down.  A line of jagged ice streaks along the ground, racing toward you!",
    topple: "Despite desperate windmilling to catch its balance, a behemothic gorefrost golem topples toward you!  You leap to the side and avoid being flattened as the golem topples over with a thunderous crash!",
    major_elemental_wave: "Intense light begins to bleed from within a behemothic gorefrost golem, shimmering blue and unsavory scarlet warring with one another for brilliance.  A wave of blinding elemental energy pulses from the golem, so cold that moisture in the air crystallizes into stinging frost.",
    closed_fist: "A behemothic gorefrost golem swings a colossal fist of ice at you!",
    stomp: "Raising a prodigious foot, a behemothic gorefrost golem tries to stomp on you!",
    pound: "A behemothic gorefrost golem rears back slowly and swings a mighty arm of blood-flecked ice down at you!",
    twin_hammerfists: "A behemothic gorefrost golem raises its hands high, laces them together and brings them crashing down towards you!",
    haymaker: "A behemothic gorefrost golem clenches its right fist and brings its arm back for a roundhouse punch aimed at you!",
    headbutt: "A behemothic gorefrost golem charges towards you and attempts a headbutt!",
    minor_cold: "A behemothic gorefrost golem hurls a chunk of ice at you!",
    cold_snap: "A behemothic gorefrost golem thrusts a blocky fist toward you!",

    wizards: "* Golems are great targets for [[Mana Leech (516)]] as they have a lower TD.\n* Open with [[Hand of Tonis (505)]] and prioritize keeping the golems prone. Follow up by bolting.",
    general_advice: "* Like many other creatures of this type, these golems' high amount of health and immunity to being killed by lethal crits is offset by low DS. This makes flurries of unaimed attacks such as assault techniques or [[mstrike]]s backed up by [[Two Weapon Combat]], assault techniques or mstrikes using [[Brawling|unarmed combat]], or repeated attacks backed up by [[Celerity (506)]] relatively effective.\n* These golems take additional damage from [[Fire critical table|fire]], though the exact mechanics of how aren't known at the time of this writing.\n* Weapon techniques and [[combat maneuvers]] that knock golems prone and inflict Staggered, like [[Twin Hammerfists]], [[Sweep]], or [[Tackle]], can often stall out golems since their combat rounds are fairly slow and they don't have high [[Standard_maneuver_roll|SMR]] defense.",

  }
}
