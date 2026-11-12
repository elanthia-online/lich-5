# D3 (WP3b, decided): an eval action whose body re-sets the variable it watches re-enters
# Script.TriggerVariableChanged without bound (Script.cs:1358-1433 R, Monitor re-entrant);
# genieflow on Remix: "Stack overflow." and the process dies (evidence-wp3b/p08). Ours stops
# the chain at DispatchDepth::LIMIT with one script error and the script stops.
action math n add 1;var x 1 when eval %x = 1
var n 0
var x 1
echo after n=%n
