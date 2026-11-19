# Synthetic parse-coverage script (the constructs of a large real-world casting script)
# debug 5
put #script abort all except parse_coverage
if ("$looptask" != ".parse_coverage") then put #var looptask .parse_coverage
if ($triggersloaded != 1) then
{
    put .trigger_setup
    exit
}
var notarget 0
if ($bout_over = 1) then goto StopDead
if ($SpellTimer.QuietVeil.active = 1) then
{
    put #var noability 1
    put #class veilrecover on
    put .rest
}
if ($unixtime > $hardrecover) then put #var hardused 0
var alt 0
var cast 0
var endmessage 0
var loopprep 0

IncSight:
var targetvisible IncBook
var targetnotvisible IncBook
include sightcheck.cmd

IncBook:
var bookreturn Main
include parse_coverage_book.cmd

Main:
    # put #var backstop #evalmath ($backstop + 1)
    if ($standing = 0) then put stand
    if ("$righthand" != "Empty") then goto StowRight
    if matchre ("$roomobjs" , "\bgoblin|\bcrate") then goto Target
    if !matchre ("$roomname" , "Quiet Hall") then goto CheckLoop
    if ($handhurt = 1) then var needsmain 1
    if ($noaim = 1) then action remove ^Your pattern comes apart as it meets the dull fog\.
    if ($noaim = 1) then action var fogged 1 when ^Your pattern comes apart as it meets the dull fog\.
    if ("$altname" != "Iron Ward") then matchre AltCharge ^Your carved token hums softly as the pattern you were tracing with it completes\.$
    if ($SpellTimer.IronWard.duration < 2) then
    {
        put #echo >Conversation #000000 *** No Ward On
        put #var wardneeded 1
    }
    else put #var waittime #evalmath ($unixtime + %waitsec)
    if ($wardneeded = 1) then goto WardCast
    goto CheckLoop

StowRight:
    put stow right
    pause
    goto Main

Target:
    action var notarget 1 when ^There is nothing else to face\!$
    action var outofrange 1 when ^You aren't close enough
    action put #var markarm #evalmath ($unixtime + 480) when sticky paste against.*arm\!$
    put target goblin
    matchre Target ^\.\.\.wait|^Sorry, you may only type
    matchre TargetDone ^You begin to weave|^You trace
    matchre NoTarget ^There is nothing else to face
    matchwait 5
    goto CheckLoop

TargetDone:
    action remove ^There is nothing else to face\!$
    eval cleanname replacere("%cleanname", "\w+ ", "")
    math loopcount add 1
    math waittime subtract $unixtime
    if (%waittime > 0) then pause %waittime
    goto CheckLoop

NoTarget:
    echo **** No Target ****
    goto CheckLoop

WardCast:
    put prep ward
    match WardDone You feel fully ready to use your ability.
    match WardFail You don't have a pattern prepared
    match HandHurt You can't pick that up with your hand that damaged.
    matchwait 
WardDone:
    put cast
    put #var wardneeded 0
    goto %bookreturn
WardFail:
HandHurt:
    put #class abilityprepared off
    goto CheckLoop

CheckLoop:
    if ($loopon = 1) then
    {
        if ($loopstarted < $unixtime) then put #var loopon 0
    } 
    if (%loopcount > 3)  then goto StopDead
    goto Main

StopDead:
    echo ***** Stopped *****
    exit
