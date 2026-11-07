# WP7a-r1 parity B1 (p05 shape). A chain of first runs (this -> b -> c -> d): d ends in its first
# run, c and b pause in theirs. None is listed before this script's run ends (a-after-b none), then
# all at once in launch order (AddScripts over m_oScriptListNew, FormMain.cs:4691-4699, 3809-3835 R):
# never the grandchild first. Listed, b and c see the #parse; `#script abort all except` ends them.
echo a-start $scriptlist
put ._t167_b
echo a-after-b $scriptlist
pause 0.1
echo a-list1 $scriptlist
put #parse PING
pause 0.1
echo a-list2 $scriptlist
put #script abort all except t167_grandchild_chain_order
pause 0.1
echo a-list3 $scriptlist
