# G20: `#script pause` of the running script stops its row loop before the next row (RunScript breaks when
# ScriptPaused, Script.cs:1731-1734 R); `#script resume` from another script continues at that row
# (ResumeScript -> RunScript, Script.cs:1079-1106 R). The first pause puts the script in the list.
put ._t153_resumer
pause 0.1
echo before
put #script pause t153_pause_self_midrun
echo after-pause-row
pause 0.2
echo end
