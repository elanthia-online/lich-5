# D3 (WP3b, decided): two scripts whose eval actions set the global the other one watches.
# Remix runs each TriggerVariableChanged synchronously on the changing thread and recurses until
# the client dies (genieflow: genie-crash at FormMain.cs:4725 R after 200 levels, evidence-wp3b
# pp). Ours queues each change on the other script with its D3 depth; the count continues there,
# so the chain stops at DispatchDepth::LIMIT with one script error.
action put #var b 1 when eval $a = 1
put ._d3_var_pong
pause 0.1
put #var a 1
pause 1
echo a-done
