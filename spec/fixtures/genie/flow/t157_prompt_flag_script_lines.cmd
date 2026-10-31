# B1 (WP6-r1): the script-status lines Remix prints to the main window clear m_bLastRowWasPrompt
# (Script.PrintText -> FormMain.AddText, FormMain.cs:5100-5122, 5611-5614 R): "[Script loaded: ...]"
# (Script.cs:1995 R), "[Script paused|resumed: ...]" (Script.cs:1062, 1087 R), "[Script aborted! ...]"
# (Script.cs:1157 R), "[Script finished ...]" (Script.cs:1763 R). Lich prints its own lines there
# ("--- Lich: x active." / "paused." / "unpaused." / "has exited."), so the next prompt is shown.
action var seen %seen|$0 when ^R?>
var seen start
waitfor START
pause 1
put ._t157_child
pause 1
put #script pause _t157_child
pause 1
put #script resume _t157_child
pause 1
put #script abort _t157_child
pause 1
put ._t157_quick
pause 1
echo seen=%seen
