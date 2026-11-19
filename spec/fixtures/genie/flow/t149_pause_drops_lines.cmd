# G20: a #script-paused script drops the game lines that arrive while it is paused (TriggerParse returns
# for a paused script, Script.cs:1179-1184 R): "HIT one" is lost, "HIT two" fires the action and the waitfor.
put ._t149_b
pause 0.1
put #script pause _t149_b
pause 0.3
put #script resume _t149_b
pause 0.3
put #script abort _t149_b
echo done
