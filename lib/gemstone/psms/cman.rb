## breakout for CMan released with PSM3
## updated for Ruby 3.2.1 and new Infomon module
module Lich
  module Gemstone
    module CMan
      def self.cman_lookups
        [{ long_name: 'acrobats_leap',           short_name: 'acrobatsleap',     cost:  0 },
         { long_name: 'bearhug',                 short_name: 'bearhug',          cost: 10 },
         { long_name: 'berserk',                 short_name: 'berserk',          cost: 20 },
         { long_name: 'block_specialization',    short_name: 'blockspec',        cost:  0 },
         { long_name: 'bull_rush',               short_name: 'bullrush',         cost: 14 },
         { long_name: 'burst_of_swiftness',      short_name: 'burst',            cost: Lich::Util.normalize_lookup('Cooldowns', 'burst_of_swiftness') ? 60 : 30 },
         { long_name: 'cheapshots',              short_name: 'cheapshots',       cost:  7 },
         { long_name: 'combat_focus',            short_name: 'focus',            cost:  0 },
         { long_name: 'combat_mobility',         short_name: 'mobility',         cost:  0 },
         { long_name: 'combat_movement',         short_name: 'cmovement',        cost:  0 },
         { long_name: 'combat_toughness',        short_name: 'toughness',        cost:  0 },
         { long_name: 'coup_de_grace',           short_name: 'coupdegrace',      cost: 20 },
         { long_name: 'crowd_press',             short_name: 'cpress',           cost:  9 },
         { long_name: 'cunning_defense',         short_name: 'cdefense',         cost:  0 },
         { long_name: 'cutthroat',               short_name: 'cutthroat',        cost: 14 },
         { long_name: 'dirtkick',                short_name: 'dirtkick',         cost:  7 },
         { long_name: 'disarm_weapon',           short_name: 'disarm',           cost:  7 },
         { long_name: 'dislodge',                short_name: 'dislodge',         cost:  7 },
         { long_name: 'divert',                  short_name: 'divert',           cost:  7 },
         { long_name: 'duck_and_weave',          short_name: 'duckandweave',     cost: 20 },
         { long_name: 'dust_shroud',             short_name: 'shroud',           cost: 10 },
         { long_name: 'evade_specialization',    short_name: 'evadespec',        cost:  0 },
         { long_name: 'eviscerate',              short_name: 'eviscerate',       cost: 14 },
         { long_name: 'executioners_stance',     short_name: 'executioner',      cost: 20 },
         { long_name: 'exsanguinate',            short_name: 'exsanguinate',     cost: 15 },
         { long_name: 'eyepoke',                 short_name: 'eyepoke',          cost:  7 },
         { long_name: 'feint',                   short_name: 'feint',            cost:  9 },
         { long_name: 'flurry_of_blows',         short_name: 'flurry',           cost: 20 },
         { long_name: 'footstomp',               short_name: 'footstomp',        cost: 7 },
         { long_name: 'garrote',                 short_name: 'garrote',          cost: 10 },
         { long_name: 'grappel_specialization',  short_name: 'grapplespec',      cost:  0 },
         { long_name: 'griffins_voice',          short_name: 'griffin',          cost: 20 },
         { long_name: 'groin_kick',              short_name: 'gkick',            cost:  7 },
         { long_name: 'hamstring',               short_name: 'hamstring',        cost:  9 },
         { long_name: 'haymaker',                short_name: 'haymaker',         cost:  9 },
         { long_name: 'headbutt',                short_name: 'headbutt',         cost:  9 },
         { long_name: 'inner_harmony',           short_name: 'iharmony',         cost: 20 },
         { long_name: 'internal_power',          short_name: 'ipower',           cost: 20 },
         { long_name: 'ki_focus',                short_name: 'kifocus',          cost: 20 },
         { long_name: 'kick_specialization',     short_name: 'kickspec',         cost:  0 },
         { long_name: 'kneebash',                short_name: 'kneebash',         cost:  7 },
         { long_name: 'leap_attack',             short_name: 'leapattack',       cost: 15 },
         { long_name: 'mighty_blow',             short_name: 'mblow',            cost: 15 },
         { long_name: 'mug',                     short_name: 'mug',              cost: 15 },
         { long_name: 'nosetweak',               short_name: 'nosetweak',        cost:  7 },
         { long_name: 'parry_specialization',    short_name: 'parryspec',        cost:  0 },
         { long_name: 'precision',               short_name: 'precision',        cost:  0 },
         { long_name: 'predators_eye',           short_name: 'predator',         cost: 20 },
         { long_name: 'punch_specialization',    short_name: 'punchspec',        cost:  0 },
         { long_name: 'retreat',                 short_name: 'retreat',          cost: 30 },
         { long_name: 'rolling_krynch_stance',   short_name: 'krynch',           cost: 20 },
         { long_name: 'shield_bash',             short_name: 'sbash',            cost:  9 },
         { long_name: 'side_by_side',            short_name: 'sidebyside',       cost:  0 },
         { long_name: 'slippery_mind',           short_name: 'slipperymind',     cost:  0 },
         { long_name: 'spell_cleave',            short_name: 'scleave',          cost:  7 },
         { long_name: 'spell_parry',             short_name: 'sparry',           cost:  0 },
         { long_name: 'spell_thieve',            short_name: 'sthieve',          cost:  7 },
         { long_name: 'spike_focus',             short_name: 'spikefocus',       cost:  0 },
         { long_name: 'spin_attack',             short_name: 'sattack',          cost:  0 },
         { long_name: 'staggering_blow',         short_name: 'sblow',            cost: 15 },
         { long_name: 'stance_perfection',       short_name: 'stance',           cost:  0 },
         { long_name: 'stance_of_the_mongoose',  short_name: 'mongoose',         cost: 20 },
         { long_name: 'striking_asp',            short_name: 'asp',              cost: 20 },
         { long_name: 'stun_maneuvers',          short_name: 'stunman',          cost: 10 },
         { long_name: 'subdue',                  short_name: 'subdue',           cost:  9 },
         { long_name: 'sucker_punch',            short_name: 'spunch',           cost:  7 },
         { long_name: 'sunder_shield',           short_name: 'sunder',           cost:  7 },
         { long_name: 'surge_of_strength',       short_name: 'surge',            cost: Lich::Util.normalize_lookup('Cooldowns', 'surge_of_strength') ? 60 : 30 },
         { long_name: 'sweep',                   short_name: 'sweep',            cost:  7 },
         { long_name: 'swiftkick',               short_name: 'swiftkick',        cost:  7 },
         { long_name: 'tackle',                  short_name: 'tackle',           cost:  7 },
         { long_name: 'tainted_bond',            short_name: 'tainted',          cost:  0 },
         { long_name: 'templeshot',              short_name: 'templeshot',       cost:  7 },
         { long_name: 'throatchop',              short_name: 'throatchop',       cost:  7 },
         { long_name: 'trip',                    short_name: 'trip',             cost:  7 },
         { long_name: 'true_strike',             short_name: 'truestrike',       cost: 15 },
         { long_name: 'unarmed_specialist',      short_name: 'unarmedspec',      cost:  0 },
         { long_name: 'vault_kick',              short_name: 'vaultkick',        cost: 30 },
         { long_name: 'weapon_specialization',   short_name: 'wspec',            cost:  0 },
         { long_name: 'whirling_dervish',        short_name: 'dervish',          cost: 20 }]
      end

      @@combat_mans = {
        "acrobats_leap"          => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Acrobat\'s Leap combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "bearhug"                => {
          :cost  => 10,
          :type  => "concentration",
          :regex => Regexp.union(/You charge towards .+ and attempt to grasp .+ in a ferocious bearhug!/,
                                 /.+ manages to fend off your grasp\!/),
          :usage => "bearhug"
        },
        "berserk"                => {
          :cost  => 20,
          :type  => "attack",
          :regex => /Everything around you turns red as you work yourself into a berserker's rage\!/,
          :usage => "berserk"
        },
        "block_specialization"   => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Block Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "bull_rush"              => {
          :cost  => 14,
          :type  => "area of effect",
          :regex => /You dip your shoulder and rush towards an .+!/,
          :usage => "bullrush"
        },
        "burst_of_swiftness"     => {
          :cost               => Lich::Util.normalize_lookup('Cooldowns', 'burst_of_swiftness') ? 60 : 30,
          :type               => "buff",
          :regex              => Regexp.union(/You prepare yourself to move swiftly at a moment\'s notice\./,
                                              /You prepare yourself to move swiftly at a moment\'s notice, overcoming the fatigue from your previous exertion\./),
          :usage              => "burst",
          :ignorable_cooldown => true
        },
        "cheapshots"             => {
          :cost  => 7,
          :type  => "setup",
          :regex => /You should activate Footstomp, Nosetweak, Templeshot, Kneebash, Eyepoke, Throatchop or Swiftkick instead\./,
          :usage => nil
        },
        "combat_focus"           => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Combat Focus combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "combat_mobility"        => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Combat Mobility maneuver works automatically when you are attacked\./,
          :usage => nil
        },
        "combat_movement"        => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Combat Movement combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "combat_toughness"       => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Combat Toughness combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "coup_de_grace"          => {
          :cost  => 20,
          :type  => "attack",
          :regex => Regexp.union(/You lunge towards .+, intending to finish [a-z]+ off\!/, # Standard
                                 /You move towards .+ to finish [a-z]+ off, but [a-z]+ isn\'t injured enough to be susceptible to a Coup de Grace\./, # Standard
                                 /You advance upon .+ with grim finality\./, # RW2025
                                 /As .+ shows signs of weakness, you seize the opportunity to launch a mortal blow\!/, # RW2025
                                 /Seeing your chance, you lunge toward .+ with its death your only goal\!/, # RW2025
                                 /As .+ falters, you surge forward with murderous intent\!/), # RW2025
          :usage => "coupdegrace"
        },
        "crowd_press"            => {
          :cost  => 9,
          :type  => "setup",
          :regex => /You approach .+\./,
          :usage => "cpress"
        },
        "cunning_defense"        => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Cunning Defense combat maneuver is always active once you have learned it./,
          :usage => nil
        },
        "cutthroat"              => {
          :cost  => 14,
          :type  => "setup",
          :regex => Regexp.union(/You spring from hiding and attempt to slit .+ throat with your .+\!/,
                                 /For this to work, you\'ll need to take your target by surprise\.  Try hiding first\./,
                                 /You need to be holding a weapon in your right hand in order to use cutthroat\./,
                                 /The .+ is too cumbersome to use with cutthroat./),
          :usage => "cutthroat"
        },
        "dirtkick"               => {
          :cost  => 7,
          :type  => "setup",
          :regex => /After a quick assessment of your surroundings\, you haul back with one foot and let it fly\!/, # there is probably a climate/terrain combo where there's not dirt to kick, but was unable to test/find one.
          :usage => "dirtkick"
        },
        "disarm_weapon"          => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You swing your .+ at .+\!/,
                                 /Choosing your opening, you attempt to disarm .+ with your empty hand!/,
                                 /You haven\'t learned how to disarm without a weapon\!/),
          :usage => "disarm"
        },
        "dislodge"               => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/.+ does not currently have any suitable weapons lodged in .+\./,
                                 /You rush toward .+ with an open hand, attempting to dislodge .+ from .+\!/),
          :usage => "dislodge"
        },
        "divert"                 => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You throw your voice behind .+ and .+ attention is diverted by the noise\!/,
                                 /Maybe you should try to divert .+ in a different fashion\./,
                                 /You can\'t find a valid direction in which to push the .+\./,
                                 /Silently, you inhale and prepare your diversion\./),
          :usage => "divert"
        },
        "duck_and_weave"         => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You balance your posture and narrow your eyes, preparing to misdirect your foes\' attacks\./,
                                 /You check that your posture remains well-balanced and continue to focus on the misdirection of your foes\' attacks\./),
          :usage => "duckandweave"
        },
        "dust_shroud"            => {
          :cost  => 10,
          :type  => "buff",
          :regex => /You quickly begin kicking up as much dirt as you can\!/, # there is probably a climate/terrain combo where there's not dirt to kick, but was unable to test/find one.
          :usage => "shroud"
        },
        "evade_specialization"   => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Evade Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "eviscerate"             => {
          :cost  => 14,
          :type  => "area of effect",
          :regex => Regexp.union(/The .+ abdomen is out of reach\!/,
                                 /You uncoil from the shadows, your .+ poised to eviscerate .+\!/,
                                 /You can\'t use eviscerate with empty hands\!/),
          :usage => "eviscerate"
        },
        "executioners_stance"    => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Executioner\'s Stance, altering your grip and posture to minimize the loss of momentum when striking down a foe\./,
                                 /You re\-settle into the Executioner\'s Stance, re\-altering your grip and posture to minimize the loss of momentum when striking down a foe\./),
          :usage => "executioner"
        },
        "exsanguinate"           => {
          :cost  => 15,
          :type  => "attack",
          :regex => /You lunge at .+, your .+ a blur of .+ in your eagerness to spill [a-z]+ blood\!/,
          :usage => "exsanguinate"
        },
        "eyepoke"                => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/The .+ (?:right|left) eye is out of reach\!/,
                                 /You jab a finger at the eye of .+\!/),
          :usage => "eyepoke"
        },
        "feint"                  => {
          :cost  => 9,
          :type  => "setup",
          :regex => /You feint .+\./,
          :usage => "feint"
        },
        "flurry_of_blows"        => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume a stance suitable to unleash a flurry of blows\./,
                                 /You re\-settle into a stance suitable to unleash a flurry of blows\./),
          :usage => "flurry"
        },
        "footstomp"              => {
          :cost  => 7,
          :type  => "setup",
          :regex => /You raise your heel high, attempting to footstomp .+\!/,
          :usage => "footstomp"
        },
        "garrote"                => {
          :cost  => 10,
          :type  => "concentration",
          :regex => Regexp.union(/You fling your garrote around .+? neck and snap it taut\.  Success!/,
                                 /You need to have your other hand clear to garrote something\./,
                                 /You need to be holding a garrote\./,
                                 /You attempt to slip the garrote around .+? neck, but it catches the movement and dodges away just in time\./),
          :usage => "garrote"
        },
        "grappel_specialization" => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Grapple Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "griffins_voice"         => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Griffin\'s Voice stance, altering your breathing patterns to maximize the efficiency of your warcries\./,
                                 /You re-settle into the Griffin\'s Voice stance, re-altering your breathing patterns to maximize the efficiency of your warcries\./),
          :usage => "griffin"
        },
        "groin_kick"             => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You attempt to deliver a kick to .+ groin!/, # Standard
                                 /Leaning close to .+, you quickly raise your knee in an attempt to make debilitating contact with [a-z]+ groin\!/, # RW2025
                                 /Scuffing your foot upon the ground, you pivot at the hip, targeting your foot at .+ groin\!/, # RW2025
                                 /Performing a shuffling skip, you viciously kick out at .+ groin with malicious intent\!/, # RW2025
                                 /You aim a vicious kick square at .+ nether regions\!/), # RW2025
          :usage => "gkick"
        },
        "hamstring"              => {
          :cost  => 9,
          :type  => "setup",
          :regex => Regexp.union(/You lunge forward and try to hamstring .+ with your .+!/,
                                 /The .+ is too unwieldy for that\./,
                                 /You need to be holding a weapon capable of slashing to do that\./),
          :usage => "hamstring"
        },
        "haymaker"               => {
          :cost  => 9,
          :type  => "setup",
          :regex => Regexp.union(/You clench your right fist and bring your arm back for a roundhouse punch aimed at .+!/,
                                 /You can\'t use haymaker with .+!/),
          :usage => "haymaker"
        },
        "headbutt"               => {
          :cost  => 9,
          :type  => "setup",
          :regex => Regexp.union(/You charge towards .+ and attempt to headbutt .+!/, # Standard
                                 /Coiling your trapezius muscles, you feel your neck tense before springing into action and slamming your head down toward .+\!/, # RW2025
                                 /Shrugging almost casually, you quickly snap your head for?ward in an attempt to headbutt .+\!/, # RW2025
                                 /Rising on your tip toes, you cock back your head and slam it down towards .+\!/, # RW2025
                                 /Bellowing like an angry bull, you lower your head and charge straight at .+\!/), # RW2025
          :usage => "headbutt"
        },
        "inner_harmony"          => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You center your mind, body and soul and enter a state of inner harmony\./,
                                 /You continue in your state of inner harmony\./),
          :usage => "iharmony"
        },
        "internal_power"         => {
          :cost  => 20,
          :type  => "buff",
          :regex => /You concentrate on restoring your internal well\-being\./,
          :usage => "ipower"
        },
        "ki_focus"               => {
          :cost  => 20,
          :type  => "buff",
          :regex => Regexp.union(/You summon your inner ki and focus it to enhance your next attack\./,
                                 /You have already summoned your inner ki and are ready for a devastating attack\./),
          :usage => "kifocus"
        },
        "kick_specialization"    => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Kick Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "kneebash"               => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You reverse your weapon and swing the blunt end down at the knee of .+\!/,
                                 /You clench your fist tightly and snap it down at the knee of .+\!/,
                                 /You do not know how to kneebash barehanded yet\!/),
          :usage => "kneebash"
        },
        "leap_attack"            => {
          :cost  => 15,
          :type  => "attack",
          :regex => Regexp.union(/.+ isn\'t flying\.  Maybe you should just attack it\?/,
                                 /You sprint toward .+ and leap into the air\!/,
                                 /.+ is flying, but low enough for you to attack it\./),
          :usage => "leapattack"
        },
        "mighty_blow"            => {
          :cost  => 15,
          :type  => "attack",
          :regex => Regexp.union(/You need to be holding a weapon in your right hand to use this maneuver\./,
                                 /Tightening your grip on your .+, you strike out at .+ with all of your might!/),
          :usage => "mblow"
        },
        "mug"                    => {
          :cost  => 15,
          :type  => "attack",
          :regex => /You boldly accost .+, your attack masking your larcenous intent!/,
          :usage => "mug"
        },
        "nosetweak"              => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/The .+ head is out of reach\!/,
                                 /You reach out and grab at .+ nose!/),
          :usage => "nosetweak"
        },
        "parry_specialization"   => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Parry Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "precision"              => {
          :cost  => 0,
          :type  => "passive",
          :regex => /Usage\: CMAN PRECIS \<damage type\>/,
          :usage => nil
        },
        "predators_eye"          => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You begin to survey your surroundings with a Predator\'s Eye\./,
                                 /You continue to survey your surroundings with a Predator\'s Eye\./),
          :usage => "predator"
        },
        "punch_specialization"   => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Punch Specialization combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "retreat"                => {
          :cost  => 30,
          :type  => "buff",
          :regex => /You withdraw, disengaging from .+\./,
          :usage => "retreat"
        },
        "rolling_krynch_stance"  => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Rolling Krynch Stance\./,
                                 /You re\-settle into the Rolling Krynch Stance\./),
          :usage => "krynch"
        },
        "shield_bash"            => {
          :cost  => 9,
          :type  => "setup",
          :regex => /You lunge forward at .* with your .* and attempt a shield bash\!/,
          :usage => "sbash"
        },
        "side_by_side"           => {
          :cost  => 0,
          :type  => "passive",
          :regex => /Side by Side is automatically active whenever you are grouped with other characters\./,
          :usage => nil
        },
        "slippery_mind"          => {
          :cost  => 0,
          :type  => "martial stance",
          :regex => /You focus inward and prepare to blank your mind at a moment\'s notice\./, # reapply message not missing, just the same
          :usage => "slipperymind"
        },
        "spell_cleave"           => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You hang back for a moment and concentrate on the magical wards surrounding .+?, before unleashing your attack upon them!/,
                                 /You hang back for a moment and attempt to concentrate on the magical wards surrounding .+?, but are unable to discern the presence of any at all\./,
                                 /You remain mentally drained from your last attempt to perceive the threads that connect a magical ward to its bearer\./,
                                 /You might have more success with anti-magical equipment\./),
          :usage => "scleave"
        },
        "spell_parry"            => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Spell Parry combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "spell_thieve"           => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You might have more success with anti-magical equipment\./,
                                 /You can't use spell thieve with empty hands!/,
                                 /You hang back for a moment and concentrate on the magical wards surrounding .+?, before sneaking in an attack on them!/,
                                 /You hang back for a moment and attempt to concentrate on the magical wards surrounding .+?, but are unable to discern the presence of any at all\./),
          :usage => "sthieve"
        },
        "spike_focus"            => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Armor Spike Focus combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "spin_attack"            => {
          :cost  => 0,
          :type  => "attack",
          :regex => Regexp.union(/You let out a shrill yell and leap, spinning through the air and into the fracas\!/, # Standard
                                 /You spin on your toes, deliberate in your motion as you lunge at .+\!/, # RW2025
                                 /Giving voice to manic laughter, you whirl toward .+ with vicious glee\!/, # RW2025
                                 /Snapping around, you pivot on one foot and spin toward .+\!/, # RW2025
                                 /Silent and intent, you pivot on the ball of one foot and whirl toward .+\!/), # RW2025
          :usage => "sattack"
        },
        "staggering_blow"        => {
          :cost  => 15,
          :type  => "attack",
          :regex => Regexp.union(/Winding back with your .+, you launch yourself at .+ with staggering might!/,
                                 /You need to be holding an appropriate weapon before attempting this maneuver\./),
          :usage => "sblow"
        },
        "stance_perfection"      => {
          :cost  => 0,
          :type  => "passive",
          :regex => /You are currently using .+ of your combat skill to defend yourself\./,
          :usage => nil
        },
        "stance_of_the_mongoose" => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Stance of the Mongoose, ready to retaliate instantly against your foes\./,
                                 /You re\-settle into the Stance of the Mongoose, ready to retaliate instantly against your foes\./),
          :usage => "mongoose"
        },
        "striking_asp"           => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Striking Asp Stance, ready to find the right position for a quick strike\./,
                                 /You re\-settle Striking Asp Stance, ready to find the right position for a quick strike\./),
          :usage => "asp"
        },
        "stun_maneuvers"         => {
          :cost  => 10,
          :type  => "buff",
          :regex => Regexp.union(/Usage: CMAN STUNMAN \[option\]/,
                                 /You're not stunned\./,
                                 /You try to command your muscles and you can almost feel them react\!/,
                                 /You shakily command your muscles to ready a shield\./,
                                 /You shakily command your muscles to ready a suitable weapon\./,
                                 /You successfully command your resistant muscles to remove .+ from in your .+\./,
                                 /You stumble about in a daze, trying to regain your balance\./,
                                 /You struggle valiantly against the effects of the stun as you attempt to stand up\./,
                                 /You successfully command your resistant muscles to pick up .+\./,
                                 /You attempt to blend with the surroundings, and feel confident that no one has noticed your doing so\./, # There may be a non-standard failure message for this.
                                 /You are now in a .+ stance\./,
                                 /You stumble about in a daze, trying to regain your balance\./),
          :usage => "stunman"
        },
        "subdue"                 => {
          :cost  => 9,
          :type  => "setup",
          :regex => Regexp.union(/You haven\'t learned how to subdue without a weapon\!/,
                                 /You spring from hiding and aim a blow at .+ head\!/,
                                 /The .+ head is out of reach\!/,
                                 /For this to work, you\'ll need to take your target by surprise\.  Try hiding first\./),
          :usage => "subdue"
        },
        "sucker_punch"           => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/The .+ back is out of reach\!/,
                                 /You punch .+ in the lower back\!/,
                                 /You deliver a quick punch to .+ lower back\!/,
                                 /You deliver a solid punch to .+ lower back with your hand\!/),
          :usage => "spunch"
        },
        "sunder_shield"          => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You can\'t use sunder shield with empty hands!/,
                                 /You drive your .+ directly at .+ in an attempt to split it asunder!/),
          :usage => "sunder"
        },
        "surge_of_strength"      => {
          :cost               => Lich::Util.normalize_lookup('Cooldowns', 'surge_of_strength') ? 60 : 30,
          :type               => "buff",
          :regex              => /You focus deep within yourself, searching for untapped sources of strength\./,
          :usage              => "surge",
          :ignorable_cooldown => true
        },
        "sweep"                  => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You crouch and sweep a leg at .+\!/,
                                 /You cannot sweep .+\./),
          :usage => "sweep"
        },
        "swiftkick"              => {
          :cost               => 7,
          :type               => "setup",
          :regex              => /You spin around behind .+, attempting a swiftkick\!/,
          :usage              => "swiftkick",
          :ignorable_cooldown => true
        },
        "tackle"                 => {
          :cost  => 7,
          :type  => "setup",
          :regex => /You hurl yourself at .+!/,
          :usage => "tackle"
        },
        "tainted_bond"           => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Tainted Bond combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "templeshot"             => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/The .+ head is out of reach\!/,
                                 /You reverse your .+ and swing the blunt end at the head of .+\!/,
                                 /You clench your fist tightly and snap it towards the head of .+\!/,
                                 /You do not know how to templeshot barehanded yet\!/),
          :usage => "templeshot"
        },
        "throatchop"             => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/The .+ neck is out of reach\!/,
                                 /You swing your rigid hand at the throat of .+\!/,
                                 /You chop at .+ throat with your .+\!/,
                                 /You do not know how to throatchop barehanded yet\!/),
          :usage => "throatchop"
        },
        "trip"                   => {
          :cost  => 7,
          :type  => "setup",
          :regex => Regexp.union(/You can\'t reach far enough to trip anything with .+\./,
                                 /With a fluid whirl, you plant .+ firmly into the ground near .+ and jerk the weapon sharply sideways\./),
          :usage => "trip"
        },
        "true_strike"            => {
          :cost  => 15,
          :type  => "attack",
          :regex => /Determined, you resolve that your next attack will strike true\./,
          :usage => "truestrike"
        },
        "unarmed_specialist"     => {
          :cost  => 0,
          :type  => "passive",
          :regex => /The Unarmed Specialist combat maneuver is always active once you have learned it\./,
          :usage => nil
        },
        "vault_kick"             => {
          :cost  => 30,
          :type  => "setup",
          :regex => /You can't use vault kick with .+!/,
          :usage => "vaultkick"
        },
        "weapon_specialization"  => {
          :cost  => 0,
          :type  => "passive",
          :regex => /You are currently specialized in .+ with .+ in Weapon Specialization\./,
          :usage => nil
        },
        "whirling_dervish"       => {
          :cost  => 20,
          :type  => "martial stance",
          :regex => Regexp.union(/You assume the Whirling Dervish stance, ready to switch targets at a moment\'s notice\./,
                                 /You re-settle into the Whirling Dervish stance, ready to switch targets at a moment\'s notice\./),
          :usage => "dervish"
        }
      }

      def CMan.[](name)
        return PSMS.assess(name, 'CMan')
      end

      def CMan.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        CMan[name] >= min_rank
      end

      def CMan.affordable?(name)
        return PSMS.assess(name, 'CMan', true)
      end

      def CMan.available?(name, ignore_cooldown: false, min_rank: 1)
        return false unless CMan.known?(name, min_rank: min_rank)
        return false unless CMan.affordable?(name)
        return false if Lich::Util.normalize_lookup('Cooldowns', name) unless ignore_cooldown && @@combat_mans.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:ignorable_cooldown] # check that the request to ignore_cooldown is on something that can have the cooldown ignored as well
        return false if Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
        return true
      end

      def CMan.use(name, target = "", ignore_cooldown: false, results_of_interest: nil)
        return unless CMan.available?(name, ignore_cooldown: ignore_cooldown)
        usage = @@combat_mans.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:usage]
        return if usage.nil?

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          @@combat_mans.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex],
          /^#{name} what\?$/i
        )

        if results_of_interest.is_a?(Regexp)
          results_regex = Regexp.union(results_regex, results_of_interest)
        end

        usage_cmd = "cman #{usage}"
        if target.is_a?(GameObj)
          usage_cmd += " ##{target.id}"
        elsif target.is_a?(Integer)
          usage_cmd += " ##{target}"
        elsif target != ""
          usage_cmd += " #{target}"
        end
        waitrt?
        waitcastrt?
        usage_result = dothistimeout usage_cmd, 5, results_regex
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout usage_cmd, 5, results_regex
        end
        usage_result
      end

      def CMan.regexp(name)
        @@combat_mans.fetch(name.to_s.gsub(/[\s\-]/, '_').gsub("'", "").downcase)[:regex]
      end

      CMan.cman_lookups.each { |cman|
        self.define_singleton_method(cman[:short_name]) do
          CMan[cman[:short_name]]
        end

        self.define_singleton_method(cman[:long_name]) do
          CMan[cman[:short_name]]
        end
      }
    end
  end
end
