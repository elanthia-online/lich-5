# WP7a (G43 + malformed launch names). ClassCommand_RunScript: ScriptName = ParseArgs token 0, ToLower,
# Trim, minus the script char, + ".cmd" unless it already ends with it (FormMain.cs:4682-4687 R);
# AppendFile loads exactly ScriptDir\<name> (Script.cs:3683-3697 R): no prefix match, no other
# extension. A missing file throws from fi.Length ("File not found"), an empty one is "Unable to load
# file" (Script.cs:3698-3800 R). %scriptname is the lowercased name (Script.cs:1985-1992 R).
put .
put . x
put ..h
put .nosuch a b
put ._t162
put ._t162_inc
put ._t162_empty
put ._t162_helper.cmd x1
put ._T162_Helper y1
put ._t162_helper.CMD z1
echo done
