# WP7a-r1 parity B1 (p06 shape). Every script launched inside one synchronous run sits in
# m_oScriptListNew until the tick end, where AddScripts lists them together in launch order and
# RemoveExitedScripts drops the done ones (FormMain.cs:4691-4699, 3809-3835, 3229-3270, 8345 R).
# _t166_b launches _t166_c and ends without waiting; c paused in its first run is NOT listed yet when
# this script's `#script abort all except` walks the list, so it survives, and it is listed at the end
# of this run (t166 a|c), never before.
put ._t166_b
echo a-after-b $scriptlist
put #script abort all except t166_grandchild_reparent
echo a-after-abort
pause 0.1
echo a-list1 $scriptlist
pause 0.3
echo a-list2 $scriptlist
