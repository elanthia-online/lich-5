# WP7a ($scriptlist timing). SetScriptListVariable stores $scriptlist only at the end of the tick in
# which the list changed (FormMain.cs:4516-4541, 8349-8351 R): right after `#script abort <child>` in
# the same run the stored value still names the child; one tick later it is gone. A paused script
# stays in the list.
put ._t163_child
pause 0.1
echo before $scriptlist
put #script abort _t163_child
echo same-run $scriptlist
pause 0.1
echo next-tick $scriptlist
