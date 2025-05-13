## breakout for CMan released with PSM3
## updated for Ruby 3.2.1 and new Infomon module
module Lich
  module Gemstone
    module CMan
      @@combat_mans = {
        "acrobats_leap"          => {
          :short_name => "acrobatsleap",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Acrobat\'s Leap combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "bearhug"                => {
          :short_name => "bearhug",
          :type       => "concentration",
          :cost       => 10,
          :regex      => Regexp.union(/You charge towards .+ and attempt to grasp .+ in a ferocious bearhug!/,
                                       /.+ manages to fend off your grasp!/),
          :usage      => "bearhug"
        },
        "berserk"                => {
          :short_name => "berserk",
          :type       => "attack",
          :cost       => 20,
          :regex      => /Everything around you turns red as you work yourself into a berserker's rage!/,
          :usage      => "berserk"
        },
        "block_specialization"   => {
          :short_name => "blockspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Block Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "bull_rush"              => {
          :short_name => "bullrush",
          :type       => "area of effect",
          :cost       => 14,
          :regex      => /You dip your shoulder and rush towards an .+!/,
          :usage      => "bullrush"
        },
        "burst_of_swiftness"     => {
          :short_name         => "burst",
          :type               => "buff",
          :cost               => Lich::Util.normalize_lookup('Cooldowns', 'burst_of_swiftness') ? 60 : 30,
          :regex              => Regexp.union(/You prepare yourself to move swiftly at a moment's notice\./,
                                               /You prepare yourself to move swiftly at a moment's notice, overcoming the fatigue from your previous exertion\./),
          :usage              => "burst",
          "ignorable_cooldown" => true
        },
        "cheapshots"             => {
          :short_name => "cheapshots",
          :type       => "setup",
          :cost       => 7,
          :regex      => /You should activate Footstomp, Nosetweak, Templeshot, Kneebash, Eyepoke, Throatchop or Swiftkick instead\./,
          :usage      => nil
        },
        "combat_focus"           => {
          :short_name => "focus",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Combat Focus combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "combat_mobility"        => {
          :short_name => "mobility",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Combat Mobility maneuver works automatically when you are attacked\./,
          :usage      => nil
        },
        "combat_movement"        => {
          :short_name => "cmovement",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Combat Movement combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "combat_toughness"       => {
          :short_name => "toughness",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Combat Toughness combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "coup_de_grace"          => {
          :short_name => "coupdegrace",
          :type       => "attack",
          :cost       => 20,
          :regex      => Regexp.union(/You lunge towards .+, intending to finish [a-z]+ off!/,
                                       /You move towards .+ to finish [a-z]+ off, but [a-z]+ isn't injured enough to be susceptible to a Coup de Grace\./,
                                       /You advance upon .+ with grim finality\./,
                                       /As .+ shows signs of weakness, you seize the opportunity to launch a mortal blow!/,
                                       /Seeing your chance, you lunge toward .+ with its death your only goal!/,
                                       /As .+ falters, you surge forward with murderous intent!/),
          :usage      => "coupdegrace"
        },
        "crowd_press"            => {
          :short_name => "cpress",
          :type       => "setup",
          :cost       => 9,
          :regex      => /You approach .+\./,
          :usage      => "cpress"
        },
        "cunning_defense"        => {
          :short_name => "cdefense",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Cunning Defense combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "cutthroat"              => {
          :short_name => "cutthroat",
          :type       => "setup",
          :cost       => 14,
          :regex      => Regexp.union(/You spring from hiding and attempt to slit .+ throat with your .+!/,
                                       /For this to work, you'll need to take your target by surprise. Try hiding first\./,
                                       /You need to be holding a weapon in your right hand in order to use cutthroat\./,
                                       /The .+ is too cumbersome to use with cutthroat\./),
          :usage      => "cutthroat"
        },
        "dirtkick"               => {
          :short_name => "dirtkick",
          :type       => "setup",
          :cost       => 7,
          :regex      => /After a quick assessment of your surroundings, you haul back with one foot and let it fly!/,
          :usage      => "dirtkick"
        },
        "disarm_weapon"          => {
          :short_name => "disarm",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You swing your .+ at .+!/,
                                       /Choosing your opening, you attempt to disarm .+ with your empty hand!/,
                                       /You haven\'t learned how to disarm without a weapon!/,),
          :usage      => "disarm"
        },
        "dislodge"               => {
          :short_name => "dislodge",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/.+ does not currently have any suitable weapons lodged in .+\./,
                                       /You rush toward .+ with an open hand, attempting to dislodge .+ from .+!/),
          :usage      => "dislodge"
        },
        "divert"                 => {
          :short_name => "divert",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You throw your voice behind .+ and .+ attention is diverted by the noise!/,
                                       /Maybe you should try to divert .+ in a different fashion\./,
                                       /You can\'t find a valid direction in which to push the .+\./,
                                       /Silently, you inhale and prepare your diversion\./),
          :usage      => "divert"
        },
        "duck_and_weave"         => {
          :short_name => "duckandweave",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You balance your posture and narrow your eyes, preparing to misdirect your foes' attacks\./,
                                       /You check that your posture remains well-balanced and continue to focus on the misdirection of your foes' attacks\./),
          :usage      => "duckandweave"
        },
        "dust_shroud"            => {
          :short_name => "shroud",
          :type       => "buff",
          :cost       => 10,
          :regex      => /You quickly begin kicking up as much dirt as you can!/,
          :usage      => "shroud"
        },
        "evade_specialization"   => {
          :short_name => "evadespec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Evade Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "eviscerate"             => {
          :short_name => "eviscerate",
          :type       => "area of effect",
          :cost       => 14,
          :regex      => Regexp.union(/The .+ abdomen is out of reach!/,
                                       /You uncoil from the shadows, your .+ poised to eviscerate .+!/,
                                       /You can\'t use eviscerate with empty hands!/),
          :usage      => "eviscerate"
        },
        "executioners_stance"    => {
          :short_name => "executioner",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Executioner's Stance, altering your grip and posture to minimize the loss of momentum when striking down a foe\./,
                                       /You re-settle into the Executioner's Stance, re-altering your grip and posture to minimize the loss of momentum when striking down a foe\./),
          :usage      => "executioner"
        },
        "exsanguinate"           => {
          :short_name => "exsanguinate",
          :type       => "attack",
          :cost       => 15,
          :regex      => /You lunge at .+, your .+ a blur of .+ in your eagerness to spill [a-z]+ blood!/,
          :usage      => "exsanguinate"
        },
        "eyepoke"                => {
          :short_name => "eyepoke",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/The .+ (?:right|left) eye is out of reach!/,
                                       /You jab a finger at the eye of .+!/),
          :usage      => "eyepoke"
        },
        "feint"                  => {
          :short_name => "feint",
          :type       => "setup",
          :cost       => 9,
          :regex      => /You feint .+\./,
          :usage      => "feint"
        },
        "flurry_of_blows"        => {
          :short_name => "flurry",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume a stance suitable to unleash a flurry of blows\./,
                                       /You re-settle into a stance suitable to unleash a flurry of blows\./),
          :usage      => "flurry"
        },
        "footstomp"              => {
          :short_name => "footstomp",
          :type       => "setup",
          :cost       => 7,
          :regex      => /You raise your heel high, attempting to footstomp .+!/,
          :usage      => "footstomp"
        },
        "garrote"                => {
          :short_name => "garrote",
          :type       => "concentration",
          :cost       => 10,
          :regex      => Regexp.union(/You fling your garrote around .+? neck and snap it taut\.  Success!/,
                                       /You need to have your other hand clear to garrote something\./,
                                       /You need to be holding a garrote\./,
                                       /You attempt to slip the garrote around .+? neck, but it catches the movement and dodges away just in time\./,),
          :usage      => "garrote"
        },
        "grapple_specialization" => {
          :short_name => "grapplespec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Grapple Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "griffins_voice"         => {
          :short_name => "griffin",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Griffin's Voice stance, altering your breathing patterns to maximize the efficiency of your warcries\./,
                                       /You re-settle into the Griffin's Voice stance, re-altering your breathing patterns to maximize the efficiency of your warcries\./),
          :usage      => "griffin"
        },
        "groin_kick"             => {
          :short_name => "gkick",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You attempt to deliver a kick to .+ groin!/,
                                       /Leaning close to .+, you quickly raise your knee in an attempt to make debilitating contact with [a-z]+ groin!/,
                                       /Scuffing your foot upon the ground, you pivot at the hip, targeting your foot at .+ groin!/,
                                       /Performing a shuffling skip, you viciously kick out at .+ groin with malicious intent!/,
                                       /You aim a vicious kick square at .+ nether regions!/,),
          :usage      => "gkick"
        },
        "hamstring"              => {
          :short_name => "hamstring",
          :type       => "setup",
          :cost       => 9,
          :regex      => Regexp.union(/You lunge forward and try to hamstring .+ with your .+!/,
                                       /The .+ is too unwieldy for that\./,
                                       /You need to be holding a weapon capable of slashing to do that\./),
          :usage      => "hamstring"
        },
        "haymaker"               => {
          :short_name => "haymaker",
          :type       => "setup",
          :cost       => 9,
          :regex      => Regexp.union(/You clench your right fist and bring your arm back for a roundhouse punch aimed at .+!/,
                                       /You can't use haymaker with .+!/),
          :usage      => "haymaker"
        },
        "headbutt"               => {
          :short_name => "headbutt",
          :type       => "setup",
          :cost       => 9,
          :regex      => Regexp.union(/You charge towards .+ and attempt to headbutt .+!/,
                                       /Coiling your trapezius muscles, you feel your neck tense before springing into action and slamming your head down toward .+!/,
                                       /Shrugging almost casually, you quickly snap your head forward in an attempt to headbutt .+!/,
                                       /Rising on your tip toes, you cock back your head and slam it down towards .+!/,
                                       /Bellowing like an angry bull, you lower your head and charge straight at .+!/),
          :usage      => "headbutt"
        },
        "inner_harmony"          => {
          :short_name => "iharmony",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You center your mind, body and soul and enter a state of inner harmony\./,
                                       /You continue in your state of inner harmony\./),
          :usage      => "iharmony"
        },
        "internal_power"         => {
          :short_name => "ipower",
          :type       => "buff",
          :cost       => 20,
          :regex      => /You concentrate on restoring your internal well\-being\./,
          :usage      => "ipower"
        },
        "ki_focus"               => {
          :short_name => "kifocus",
          :type       => "buff",
          :cost       => 20,
          :regex      => Regexp.union(/You summon your inner ki and focus it to enhance your next attack\./,
                                       /You have already summoned your inner ki and are ready for a devastating attack\./),
          :usage      => "kifocus"
        },
        "kick_specialization"    => {
          :short_name => "kickspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Kick Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "kneebash"               => {
          :short_name => "kneebash",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You reverse your weapon and swing the blunt end down at the knee of .+!/,
                                       /You clench your fist tightly and snap it down at the knee of .+!/,
                                       /You do not know how to kneebash barehanded yet!/),
          :usage      => "kneebash"
        },
        "leap_attack"            => {
          :short_name => "leapattack",
          :type       => "attack",
          :cost       => 15,
          :regex      => Regexp.union(/.+ isn't flying\.  Maybe you should just attack it\?/,
                                       /You sprint toward .+ and leap into the air!/,
                                       /.+ is flying, but low enough for you to attack it\./),
          :usage      => "leapattack"
        },
        "mighty_blow"            => {
          :short_name => "mblow",
          :type       => "attack",
          :cost       => 15,
          :regex      => Regexp.union(/You need to be holding a weapon in your right hand to use this maneuver\./,
                                       /Tightening your grip on your .+, you strike out at .+ with all of your might!/),
          :usage      => "mblow"
        },
        "mug"                    => {
          :short_name => "mug",
          :type       => "attack",
          :cost       => 15,
          :regex      => /You boldly accost .+, your attack masking your larcenous intent!/,
          :usage      => "mug"
        },
        "nosetweak"              => {
          :short_name => "nosetweak",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/The .+ head is out of reach!/,
                                       /You reach out and grab at .+ nose!/),
          :usage      => "nosetweak"
        },
        "parry_specialization"   => {
          :short_name => "parryspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Parry Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "precision"              => {
          :short_name => "precision",
          :type       => "passive",
          :cost       => 0,
          :regex      => /Usage: CMAN PRECIS <damage type>/,
          :usage      => nil
        },
        "predators_eye"          => {
          :short_name => "predator",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You begin to survey your surroundings with a Predator's Eye\./,
                                       /You continue to survey your surroundings with a Predator's Eye\./),
          :usage      => "predator"
        },
        "punch_specialization"   => {
          :short_name => "punchspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Punch Specialization combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "retreat"                => {
          :short_name => "retreat",
          :type       => "buff",
          :cost       => 30,
          :regex      => /You withdraw, disengaging from .+\./,
          :usage      => "retreat"
        },
        "rolling_krynch_stance"  => {
          :short_name => "krynch",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Rolling Krynch Stance\./,
                                       /You re-settle into the Rolling Krynch Stance\./),
          :usage      => "krynch"
        },
        "shield_bash"            => {
          :short_name => "sbash",
          :type       => "setup",
          :cost       => 9,
          :regex      => /You lunge forward at .* with your .* and attempt a shield bash!/,
          :usage      => "sbash"
        },
        "side_by_side"           => {
          :short_name => "sidebyside",
          :type       => "passive",
          :cost       => 0,
          :regex      => /Side by Side is automatically active whenever you are grouped with other characters\./,
          :usage      => nil
        },
        "slippery_mind"          => {
          :short_name => "slipperymind",
          :type       => "martial stance",
          :cost       => 0,
          :regex      => /You focus inward and prepare to blank your mind at a moment's notice\./,
          :usage      => "slipperymind"
        },
        "spell_cleave"           => {
          :short_name => "scleave",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You hang back for a moment and concentrate on the magical wards surrounding .+?, before unleashing your attack upon them!/,
                                       /You hang back for a moment and attempt to concentrate on the magical wards surrounding .+?, but are unable to discern the presence of any at all\./,
                                       /You remain mentally drained from your last attempt to perceive the threads that connect a magical ward to its bearer\./,
                                       /You might have more success with anti-magical equipment\./),
          :usage      => "scleave"
        },
        "spell_parry"            => {
          :short_name => "sparry",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Spell Parry combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "spell_thieve"           => {
          :short_name => "sthieve",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You might have more success with anti-magical equipment\./,
                                       /You can't use spell thieve with empty hands!/,
                                       /You hang back for a moment and concentrate on the magical wards surrounding .+?, before sneaking in an attack on them!/,
                                       /You hang back for a moment and attempt to concentrate on the magical wards surrounding .+?, but are unable to discern the presence of any at all\./),
          :usage      => "sthieve"
        },
        "spike_focus"            => {
          :short_name => "spikefocus",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Armor Spike Focus combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "spin_attack"            => {
          :short_name => "sattack",
          :type       => "attack",
          :cost       => 0,
          :regex      => Regexp.union(/You let out a shrill yell and leap, spinning through the air and into the fracas!/,
                                       /You spin on your toes, deliberate in your motion as you lunge at .+!/,
                                       /Giving voice to manic laughter, you whirl toward .+ with vicious glee!/,
                                       /Snapping around, you pivot on one foot and spin toward .+!/,
                                       /Silent and intent, you pivot on the ball of one foot and whirl toward .+!/),
          :usage      => "sattack"
        },
        "staggering_blow"        => {
          :short_name => "sblow",
          :type       => "attack",
          :cost       => 15,
          :regex      => Regexp.union(/Winding back with your .+, you launch yourself at .+ with staggering might!/,
                                       /You need to be holding an appropriate weapon before attempting this maneuver\./),
          :usage      => "sblow"
        },
        "stance_perfection"      => {
          :short_name => "stance",
          :type       => "passive",
          :cost       => 0,
          :regex      => /You are currently using .+ of your combat skill to defend yourself\./,
          :usage      => nil
        },
        "stance_of_the_mongoose" => {
          :short_name => "mongoose",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Stance of the Mongoose, ready to retaliate instantly against your foes\./,
                                       /You re-settle into the Stance of the Mongoose, ready to retaliate instantly against your foes\./),
          :usage      => "mongoose"
        },
        "striking_asp"           => {
          :short_name => "asp",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Striking Asp Stance, ready to find the right position for a quick strike\./,
                                       /You re-settle Striking Asp Stance, ready to find the right position for a quick strike\./),
          :usage      => "asp"
        },
        "stun_maneuvers"         => {
          :short_name => "stunman",
          :type       => "buff",
          :cost       => 10,
          :regex      => Regexp.union(/Usage: CMAN STUNMAN \[option\]/,
                                       /You're not stunned\./,
                                       /You try to command your muscles and you can almost feel them react!/,
                                       /You shakily command your muscles to ready a shield\./,
                                       /You shakily command your muscles to ready a suitable weapon\./,
                                       /You successfully command your resistant muscles to remove .+ from in your .+\./,
                                       /You stumble about in a daze, trying to regain your balance\./,
                                       /You struggle valiantly against the effects of the stun as you attempt to stand up\./,
                                       /You successfully command your resistant muscles to pick up .+\./,
                                       /You attempt to blend with the surroundings, and feel confident that no one has noticed your doing so\./,
                                       /You are now in a .+ stance\./,
                                       /You stumble about in a daze, trying to regain your balance\./),
          :usage      => "stunman"
        },
        "subdue"                 => {
          :short_name => "subdue",
          :type       => "setup",
          :cost       => 9,
          :regex      => Regexp.union(/You haven't learned how to subdue without a weapon!/,
                                       /You spring from hiding and aim a blow at .+ head!/,
                                       /The .+ head is out of reach!/,
                                       /For this to work, you'll need to take your target by surprise. Try hiding first\./),
          :usage      => "subdue"
        },
        "sucker_punch"           => {
          :short_name => "spunch",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/The .+ back is out of reach!/,
                                       /You punch .+ in the lower back!/,
                                       /You deliver a quick punch to .+ lower back!/,
                                       /You deliver a solid punch to .+ lower back with your hand!/),
          :usage      => "spunch"
        },
        "sunder_shield"          => {
          :short_name => "sunder",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You can't use sunder shield with empty hands!/,
                                       /You drive your .+ directly at .+ in an attempt to split it asunder!/),
          :usage      => "sunder"
        },
        "surge_of_strength"      => {
          :short_name         => "surge",
          :type               => "buff",
          :cost               => Lich::Util.normalize_lookup('Cooldowns', 'surge_of_strength') ? 60 : 30,
          :regex              => /You focus deep within yourself, searching for untapped sources of strength\./,
          :usage              => "surge",
          "ignorable_cooldown" => true
        },
        "sweep"                  => {
          :short_name => "sweep",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You crouch and sweep a leg at .+!/,
                                       /You cannot sweep .+./),
          :usage      => "sweep"
        },
        "swiftkick"              => {
          :short_name         => "swiftkick",
          :type               => "setup",
          :cost               => 7,
          :regex              => /You spin around behind .+, attempting a swiftkick!/,
          :usage              => "swiftkick",
          "ignorable_cooldown" => true
        },
        "tackle"                 => {
          :short_name => "tackle",
          :type       => "setup",
          :cost       => 7,
          :regex      => /You hurl yourself at .+!/,
          :usage      => "tackle"
        },
        "tainted_bond"           => {
          :short_name => "tainted",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Tainted Bond combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "templeshot"             => {
          :short_name => "templeshot",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/The .+ head is out of reach!/,
                                       /You reverse your .+ and swing the blunt end at the head of .+!/,
                                       /You clench your fist tightly and snap it towards the head of .+!/,
                                       /You do not know how to templeshot barehanded yet!/),
          :usage      => "templeshot"
        },
        "throatchop"             => {
          :short_name => "throatchop",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/The .+ neck is out of reach!/,
                                       /You swing your rigid hand at the throat of .+!/,
                                       /You chop at .+ throat with your .+!/,
                                       /You do not know how to throatchop barehanded yet!/),
          :usage      => "throatchop"
        },
        "trip"                   => {
          :short_name => "trip",
          :type       => "setup",
          :cost       => 7,
          :regex      => Regexp.union(/You can't reach far enough to trip anything with .+\./,
                                       /With a fluid whirl, you plant .+ firmly into the ground near .+ and jerk the weapon sharply sideways\./),
          :usage      => "trip"
        },
        "true_strike"            => {
          :short_name => "truestrike",
          :type       => "attack",
          :cost       => 15,
          :regex      => /Determined, you resolve that your next attack will strike true\./,
          :usage      => "truestrike"
        },
        "unarmed_specialist"     => {
          :short_name => "unarmedspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /The Unarmed Specialist combat maneuver is always active once you have learned it\./,
          :usage      => nil
        },
        "vault_kick"             => {
          :short_name => "vaultkick",
          :type       => "setup",
          :cost       => 30,
          :regex      => /You can't use vault kick with .+!/,
          :usage      => "vaultkick"
        },
        "weapon_specialization"  => {
          :short_name => "wspec",
          :type       => "passive",
          :cost       => 0,
          :regex      => /You are currently specialized in .+ with .+ in Weapon Specialization\./,
          :usage      => nil
        },
        "whirling_dervish"       => {
          :short_name => "dervish",
          :type       => "martial stance",
          :cost       => 20,
          :regex      => Regexp.union(/You assume the Whirling Dervish stance, ready to switch targets at a moment's notice\./,
                                       /You re-settle into the Whirling Dervish stance, ready to switch targets at a moment's notice\./),
          :usage      => "dervish"
        }
      }

      def self.cman_lookups
        @@combat_mans.map do |long_name, psm|
          {
            long_name: long_name,
            short_name: psm[:short_name],
            cost: psm[:cost]
          }
        end
      end

      def CMan.[](name)
        return PSMS.assess(name, 'CMan')
      end

      def CMan.known?(name, min_rank: 1)
        min_rank = 1 unless min_rank >= 1 # in case a 0 or below is passed
        CMan[name] >= min_rank
      end

      def CMan.affordable?(name, forcert_count: 0)
        return PSMS.assess(name, 'CMan', true, forcert_count: forcert_count)
      end

      def CMan.available?(name, ignore_cooldown: false, min_rank: 1, forcert_count: 0)
        return false unless CMan.known?(name, min_rank: min_rank)
        return false unless CMan.affordable?(name, forcert_count: forcert_count)
        return false if Lich::Util.normalize_lookup('Cooldowns', name) unless ignore_cooldown && @@combat_mans.fetch(PSMS.name_normal(name))[:ignorable_cooldown] # check that the request to ignore_cooldown is on something that can have the cooldown ignored as well
        return false if Lich::Util.normalize_lookup('Debuffs', 'Overexerted')
        return true
      end

      def CMan.use(name, target = "", ignore_cooldown: false, results_of_interest: nil, forcert_count: 0)
        return unless CMan.available?(name, ignore_cooldown: ignore_cooldown, forcert_count: forcert_count)
        name_normalized = PSMS.name_normal(name)
        technique = @@combat_mans.fetch(name_normalized)
        usage = technique[:usage]
        return if usage.nil?

        in_cooldown_regex = /^#{name} is still in cooldown\./i

        results_regex = Regexp.union(
          PSMS::FAILURES_REGEXES,
          /^#{name} what\?$/i,
          in_cooldown_regex,
          technique[:regex],
          /^Roundtime: [0-9]+ sec\.$/,
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

        if forcert_count > 0
          usage_cmd += " forcert"
        else # if we're using forcert, we don't want to wait for rt, but we need to otherwise
          waitrt?
          waitcastrt?
        end

        usage_result = dothistimeout usage_cmd, 5, results_regex
        if usage_result == "You don't seem to be able to move to do that."
          100.times { break if clear.any? { |line| line =~ /^You regain control of your senses!$/ }; sleep 0.1 }
          usage_result = dothistimeout usage_cmd, 5, results_regex
        end
        usage_result
      end

      def CMan.regexp(name)
        @@combat_mans.fetch(PSMS.name_normal(name))[:regex]
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
