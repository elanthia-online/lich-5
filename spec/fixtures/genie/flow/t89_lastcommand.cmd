# WP5 (G39): $lastcommand is the last text Game.SendText sent to the game, from any origin
# (Game.cs:545-551 R); %lastcommand is set by `put` only, for any non-blank text incl.
# a #command (EvalPut, Script.cs:3460-3467 R). $lastinput is the last typed input
# (Game.cs:521-532 R).
echo 0 g=[$lastcommand] l=[%lastcommand]
put look
echo 1 g=[$lastcommand] l=[%lastcommand]
send smile
pause 0.1
echo 2 g=[$lastcommand] l=[%lastcommand]
put #echo hi
echo 3 g=[$lastcommand] l=[%lastcommand]
waitfor STEP1
echo 4 g=[$lastcommand] l=[%lastcommand] i=[$lastinput]
