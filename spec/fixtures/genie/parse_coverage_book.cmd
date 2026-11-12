# Synthetic ability book (included by parse_coverage.cmd)
goto BookSetup

BookSetup:
var abilitylist Iron Ward|Green Ward|Spark Ring
var abilitycount 3
if ("$preparedspell" = "None") then var prepping 0
if ($SpellTimer.GreenWard.active != 1) then goto GreenWard
if ($SpellTimer.SparkRing.active = 0) then goto SparkRing
goto %bookreturn

GreenWard:
    if ($mana < 40) then goto %bookreturn
    put #var abilityname Green Ward
    put #class casting on
    put prep gw 10
    matchre GreenWardCast ^You feel fully ready to use your ability\.|^You are already preparing
    matchre GreenWardLost ^Your pattern comes apart|^You have lost the pattern you were preparing\.
    matchwait 30
    goto %bookreturn
GreenWardCast:
    put cast
    put #var greenwardtimer #evalmath ($unixtime + 600)
    goto %bookreturn
GreenWardLost:
    echo **** Waiting for Prep ****
    goto GreenWard

SparkRing:
    if matchre ("$preparedspell" , "Spark Ring|Iron Ward") then goto %bookreturn
    put #var abilityname Spark Ring
    put prep sr
    pause 2
    put cast
    goto %bookreturn
