# WP5 (G21): a script's #var of a reserved name holds until the game next updates that
# name, then the game value wins again (one variable list, last writer wins: Globals.cs:
# 604-617 R; Game.cs:2093-2099 R). A name the game never updates keeps the #var
# ($version: set once by SetDefaultGlobalVars, Globals.cs:891 R). corpus: a tester script.
waitfor STEP1
echo a=[$invisible] o=[$roomobjs]
put #var invisible 0
put #var roomobjs mine
put #var version 9.9
echo b=[$invisible] o=[$roomobjs] v=[$version]
waitfor STEP2
echo c=[$invisible] o=[$roomobjs] v=[$version]
put #var invisible 0
echo d=[$invisible]
