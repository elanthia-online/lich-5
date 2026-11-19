# WP7a-r2 parity NB1 ($scriptlist timing). A launched script's first run happens inside its
# launcher's row (ClassCommand_RunScript -> oScript.RunScript(), FormMain.cs:4700-4714 R), and
# SetScriptListVariable runs only at the timer's tick end, after AddScripts (FormMain.cs:4516-4541,
# 8345-8351 R). So the end of a NESTED first run is not a tick end: the relaunch of _t170_c below
# aborts the listed copy (abortdupescript) and the new copy's first run ends, yet right after it
# the launcher still reads the value stored before the relaunch (naming _t170_c), not a value
# stored without the aborted copy; at the tick end the new copy is listed.
put ._t170_c a
pause 0.1
echo L0 $scriptlist
put ._t170_c b
echo L1 $scriptlist
pause 0.1
echo L2 $scriptlist
pause 1
echo L3 $scriptlist
