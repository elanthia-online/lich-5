# WP3b (G11): chained eval actions (a body's local set re-enters TriggerVariableChanged, Monitor is
# re-entrant: Script.cs:1365 R) and an eval action goto. The goto in the body is an action goto
# (ParseAction, Script.cs:2247-2268 R): m_bStopRunning stops the row loop right after `var flag 1`
# (`not-here` never runs) and the script resumes at the label on the next tick, %lastlabel = done.
action var b 1 when eval %a = 1
action echo B-FIRED %b when eval %b = 1
action goto done when eval %flag = 1
var a 1
var flag 1
echo not-here
done:
echo at-done %lastlabel
