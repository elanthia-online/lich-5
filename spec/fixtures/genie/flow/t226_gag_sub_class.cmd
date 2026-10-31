# WP10-r1 parity 8a: Command_EventClassChange toggles the gag and substitute lists too
# (FormMain.cs:7510-7514 R): a gag / sub in a class that is off no longer hides a line, so the
# line clears m_bLastRowWasPrompt (Game.cs:3075-3103 R) and the next prompt is printed again.
put #gag {^hide} {g}
put #sub {^blank.*} {} {s}
put #class g off
put #class s off
var cnt 0
action math cnt add 1 when ^>
waitfor shown one
echo off=%cnt
put #class g on
put #class s on
var cnt 0
waitfor shown two
echo on=%cnt
