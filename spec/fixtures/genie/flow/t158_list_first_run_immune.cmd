# WP7a (script-list membership, G42). A launched script joins m_oScriptList only at the end of the tick
# (ClassCommand_RunScript -> m_oScriptListNew, FormMain.cs:4678-4714 R; AddScripts, FormMain.cs:3809-3835,
# 8345 R), so `#script abort|pause` run before its first wait walk a list without it (FormMain.cs:
# 5783-5830, 5845-5903 R): a tester script's mismatched `put #script abort all except <other>` openers survive.
# $scriptlist is only stored at a tick end (SetScriptListVariable, FormMain.cs:4516-4541, 8349 R).
# Once listed, a self-abort stops at once: AbortScript sets finished, RunScript's loop breaks
# (Script.cs:1137-1165, 1726-1730 R), so "after-abort" never echoes (G42).
echo first $scriptlist
put #script abort all except nobody
put #script pause t158_list_first_run_immune
echo still-running
pause 0.1
echo listed $scriptlist
put #script abort t158_list_first_run_immune
echo after-abort
put after-abort-send
