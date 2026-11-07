# Remix vs upstream: an eval #trigger on $lastcommand whose action sends a matching command.
# Game.SendText raises VariableChanged("lastcommand") on every send (Game.cs:549-551 R). Upstream
# TriggerVariableChanged returns at depth > 1 (FormMain.cs:4677 U), so the trigger fires once.
# Remix has no depth guard (FormMain.cs:4725 R): unbounded recursion, the client process dies
# (genieflow: "genie-crash"). The trigger is defined from the trace (user input) so that the
# script's own $var expansion does not bake $lastcommand into the pattern.
pause 0.1
put ping
echo after
