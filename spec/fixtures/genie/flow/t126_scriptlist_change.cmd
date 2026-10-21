# WP3b (G11): the "scriptlist" change. FormMain's timer tick ends with SetScriptListVariable when
# the script list changed -- a script added (AddScripts), finished, aborted, paused or resumed
# (Script_EventStatusChanged) -- and raises TriggerVariableChanged("scriptlist") (FormMain.cs:
# 3481-3483, 3832, 4516-4541, 8345-8351 R). An eval action on $scriptlist fires then, and a
# waiteval on it (a tester script's shape) resumes only then: never on game text.
action echo SL $scriptlist when eval contains("$scriptlist", "_t126_helper")
put ._t126_helper
pause 0.1
put #script pause _t126_helper
pause 0.1
put #script resume _t126_helper
waiteval !contains("$scriptlist", "_t126_helper")
echo resumed $scriptlist
