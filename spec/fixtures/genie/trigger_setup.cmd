goto %triggerreturn

UntriggerSetup:
put #trigger clear
if ($triggersloaded != 0) then put #var triggersloaded 0
if ($duelsloaded != 0) then put #var duelsloaded 0
goto %triggerreturn

SetTriggers:
put #trigger {^A squat iron catapult fitted with heavy brass gears creaks loudly and makes a rattling noise as it hurls a large stone} {#var catloaded 0} {catapult}
put #trigger {^You feel ready to use your ability again\.} {#var cdtimer 0;#class cooldown off} {cooldown}
put #trigger {^The.*?iron catapult creaks as a large stone rolls into its cup|^The.*?iron catapult is already loaded|^The.*?iron catapult creaks as.*?stone settles into the cup\.} {#var catloaded 1;#var catloadtimer #evalmath (\\$unixtime + 20)} {catapult}
put #trigger {^A ring of humming sparks gathers around your wrists} {#var sparkready 1;#var sparkshot 0;#class sparkend on;#class sparkstart off} {sparkstart}
put #trigger {^The sparks around your wrists fade away\.$} {#var sparkready 0;#var sparkcheckskip #evalmath (\\$unixtime + 5);#class sparkshot off;#class sparkend off} {sparkend}
put #trigger {^Flakes of soot and smoke begin to rise from the ground as the air grows hot\.} {#var smokeon 1;#var loopstarted #evalmath (\\$unixtime + 30);#class smoke on;#class smoke2 on;#class smokestart off} {smokestart}
put #trigger {^The roof gets in the way of the smoke cloud\.} {#var indoors 1;#var smokeon 0;#var arealoop 0;#var loopstarted 0;#class smoke off;#class smoke2 off} {smoke2}
put #trigger {^A drifting ember} {#class smoke2 off} {smoke2}
put #trigger {^Your hold on the smoke cloud} {#var smokeon 0;#var arealoop 0;#class smoke off} {smoke}
put #trigger {^Reaching into the storm, you begin gathering a static charge} {#var staticon 1;#var stuncheck #evalmath (\\$unixtime + 15);#var loopstarted #evalmath (\\$unixtime + 30);#class static on;#class staticstart off} {staticstart}
put #trigger {^You let go of the storm, and the static charge fades\.} {#var staticon 0;#var arealoop 0;#class static off} {static}
put #trigger {^A cold mist begins rising slowly around you\.} {#var misty 1;#var loopstarted #evalmath (\\$unixtime + 30);#class mist on;#class miststart off} {miststart}
put #trigger {^The cold mist around you fades} {#var misty 0;#class mist off} {mist}
put #trigger {^The light around you dims, and a heavy cloak of shadow wraps itself about you\.} {#var shadeon 1;#var loopstarted #evalmath (\\$unixtime + 30);#class shade on;#class shadestart off} {shadestart}
put #trigger {^The cloak of shadow around you lifts\.} {#var shadeon 0;#class shade off} {shade}
put #trigger {^The paired charms resonate and strengthen you\.|^Your anchor stone hums, strengthening you\.} {#var nopower 0;#class powerwatcher on;#class nopower off} {nopower}
put #trigger {^You lack the needed power|^Out of power, the delicate pattern falls apart|^You lack the stored power|^You cannot find the strength to do that\.} {#var nopower 1;#var routeheavy 0;#var routeswift 0;#var routequick 0;#var routeguard 0;#var routeexact 0;#class nopower on;#class powerwatcher off} {powerwatcher}
put #trigger {^The shimmer slowly fades away from around you\.} {#var focuson 0;#class focusstart off;#class focuswatcher off} {focuswatcher}
put #trigger {^You are set, and plant your feet\!} {#var braced 1} {catapult}
put #trigger {^You close to melee range|closes to melee range on you\!$} {#var closelasttime 1;#var reachrange 1;#class backoffwatcher on;#class reachwatcher off;#class closewatcher off} {closewatcher}
put #trigger {^You close to pole weapon range|closes to pole weapon range on you\!$} {#var reachrange 1;#class backoffwatcher on;#class closewatcher on;#class reachwatcher off} {reachwatcher}
put #trigger {^You feel fully ready to use your ability\.} {#var abilityready 1;#class abilityprepared off} {abilityprepared}
put #trigger {^Your carved token hums softly as the pattern you were tracing with it completes\.} {#var altready 1;#class altprepared off} {altprepared}
put #trigger {^You wave|^You point your finger at the floor\.|^You lift your hand toward the sky\.|^A ring of pale sparks circles you|^You tap your foot firmly on the ground\.|^Threads of light run along your|^The sparks along your fingertips|^You trace a slow circle in the air|^Your knuckles glow a faint green|^A burst of bright light leaps from your|^Holding your breath, you briefly nod|^You raise your.*?cup in a toast|^You reach out toward.*?with your.*?hand\.|^As the pattern brushes the far side|^You extend your.*?hand toward.*?threads of light curling around your|^Light flickers about you as you bend the pattern to your will\.|^You sense.*?trying to take the pattern from your mind.  You deftly finish|^Your pattern comes apart|^You press your hands to your temples|^The pattern falls apart} {#if {(\\$alt = 0)} {#class abilityprepared off;#class abilitylostwatcher off;#if {(\\$aimready != 0)} {#var aimready 0};#if {(\\$charges != 0)} {#var charges 0};#if {(\\$strike != 0)} {#var strike 0};#if {(\\$hardstrike != 0)} {#var hardstrike 0};#if {(\\$hinder != 0)} {#var hinder 0};#if {(\\$wild != 0)} {#var wild 0};#if {(\\$abilityready != 0)} {#var abilityready 0};#var prepping 0;#if {(\\$charges1 != 0)} {#var charges1 0};#if {(\\$charges2 != 0)} {#var charges2 0};#if {(\\$chargelimit != 0)} {#var chargelimit 0};#var ability 0;#var abilityname 0;#var waittime 0;#if {(\\$focusused != 0)} {#var focusused 0};#class casting off};#if {(\\$alt = 1)} {#class altloss off;#class altprepared off;#var altprepping 0;#if {(\\$altcharges1 != 0)} {#var altcharges1 0};#if {(\\$altcharges2 != 0)} {#var altcharges2 0};#if {(\\$alttarget != 0)} {#var alttarget 0};#if {(\\$altchargelimit != 0)} {#var altchargelimit 0};#var altability 0;#var altabilityname 0;#if {(\\$altcharges != 0)} {#var altcharges 0};#var altprepped 0;#var altwaittime 0;#var alt 0;#if {(\\$altwild != 0)} {#var altwild 0};#if {(\\$altready != 0)} {#var altready 0};#var alttimer 0;#class casting off}} {casting}
put #trigger {^You lose track of the pattern you were tracing with a carved token with plain silver bands\.} {#var altlost 1;#var altready 0;#class altprepared off;#class altloss off} {altloss}
put #trigger {^You charge the widget|^You prime} {#if {(\\$alt = 0)} {#var charges #evalmath (\\$charges + 1)};#if {(\\$alt = 1)} {#var altcharges #evalmath (\\$altcharges + 1)};#class charging off} {charging}
put #trigger {^You are knocked out|^Rest first, then try again\.|^You are still dazed|^You do not seem to be able to|^You can't do that while tangled in a net|^You must be fully alert|^That takes a clear head\!|^You need to collect your thoughts} {#script abort all;#send .recover;#echo ;#echo #000000 **** Recovering ****} {recovery}
put #trigger {pointed only where it is aimed\.$} {#var braced 0} {catapult}
put #trigger {^Your aiming pattern|^Your aim has finished settling on|^Your aim has finished settling, but seems slightly off for this area\.} {#var aimready 1;#class aimfull off} {aimfull}
put #trigger {^Your aim drifts away|^Your focus wavers|^Your pattern drifts away|^Your focus slips for a moment, and the pattern is lost|^The strain of starting a looping pattern so recently stops you|^You have lost the pattern you were preparing\.|until.*has quietly taken away.*pattern you were shaping\!$} {#var abilitylost 1;#var aimready 0;#var abilityready 0;#class aimfull off;#class abilitylostwatcher off} {abilitylostwatcher}
put #trigger {^The air around you glimmers with a bright green light.  The light twists and turns, suddenly forming a clear barrier before fading from view\.} {#if {(\\$wardhit != 0)} {#var wardhit 0};#class wardrefresh off} {wardrefresh}
put #trigger {^You feel steady as Iron Resolve settles over you, filling you with calm certainty\.} {#if {(\\$resolvehit != 0)} {#var resolvehit 0};#class resolverefresh off} {resolverefresh}
put #trigger {^The air around you hardens into a bright green light} {#var wardhit #evalmath (\\$wardhit + 1)}
put #trigger {^Your calm certainty is shaken slightly by the blow\.|^Your calm certainty breaks under the blow\.} {#var resolvehit #evalmath (\\$resolvehit + 1)}

put #trigger {^You lift the.*?up, and.*?shimmer surrounds it\.} {#var focuson 1;#class focuswatcher on;#class focusstart off} {focusstart}

put #trigger {^With a quick flick of your wrist, you send a bright bolt of sparks} {#var sparkshot #evalmath (\\$sparkshot + 1);#class sparkshot off} {sparkshot}

put #trigger {^\[You're.*?(superbly|expertly|deftly)\sbalanced} {#if {(\\$steady != 1)} {#var steady 1};#if {(\\$evenkeel != 0)} {#var evenkeel 0};#if {(\\$wobbly != 0)} {#var wobbly 0}}
put #trigger {^\[You're.*?(firmly\sbalanced|a\slittle\soff\sbalance)} {#if {(\\$steady != 0)} {#var steady 0};#if {(\\$evenkeel != 1)} {#var evenkeel 1};#if {(\\$wobbly != 0)} {#var wobbly 0}}
put #trigger {^\[You're.*?(off balance|rather off balance|poorly balanced|very poorly balanced|badly unsteady|hopelessly unsteady|totally unsteady)} {#if {(\\$steady != 0)} {#var steady 0};#if {(\\$evenkeel != 0)} {#var evenkeel 0};#if {(\\$wobbly != 1)} {#var wobbly 1}}

put #var triggersloaded 1
put #class recovery on
put #class sparkstart off
if ($SpellTimer.SparkRing.active = 0) then 
{
    put #class sparkend off
    if ($sparkready != 0) then put #var sparkready 0
}
put #class smokestart off
if ($smokeon != 1) then put #class smoke off
put #class staticstart off
if ($staticon != 1) then put #class static off
put #class miststart off
if ($misty != 1) then put #class mist off
put #class shadestart off
if ($shadeon != 1) then put #class shade off
put #class nopower off
if ($focuson != 1) then put #class focuswatcher off
if ($altprepped != 1) then put #class altprepared off
put #class backoffwatcher off
if ("$preparedspell" = "None") then put #class abilityprepared off
put #class casting off
if ("$preparedspell" = "None") then put #class abilitylostwatcher off
if ($hardstrike != 1) then
{
    if ($strike != 1) then put #class aimfull off
}
if ($cdtimer > $unixtime) then put #class cooldown on
else put #class cooldown off
if ($nopower = 0) then put #class nopower off
if ($SpellTimer.GreenWard.active != 1) then put #class wardrefresh off
if ($SpellTimer.IronResolve.active != 1) then put #class resolverefresh off
put #class powerwatcher on
put #class closewatcher on
put #class reachwatcher on
put #class focusstart off
put #class sparkshot off
goto %triggerreturn