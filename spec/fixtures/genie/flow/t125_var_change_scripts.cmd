# WP3b (G11): global variable changes and the script list. FormMain.TriggerVariableChanged offers a
# change to every script in m_oScriptList (FormMain.cs:4964-4969 R): a script is added to that list at
# the end of the tick it was launched in (AddScripts, FormMain.cs:3809-3835, 8345 R), so its own
# `put #var foo 1` before its first wait does not reach its eval action (no EARLY at 0 ms; EARLY at 100
# ms). Another running script's eval action fires (B-SAW 1); a paused script returns at once
# (Script.cs:1360-1363 R) and the change is not replayed when it resumes (no B-SAW 2).
action echo EARLY when eval $foo = 1
put #var foo 1
pause 0.1
put #var foo 1
put ._t125_watcher
pause 0.1
put #var bar 1
pause 0.1
put #script pause _t125_watcher
put #var bar 2
pause 0.1
put #script resume _t125_watcher
pause 0.1
echo end
