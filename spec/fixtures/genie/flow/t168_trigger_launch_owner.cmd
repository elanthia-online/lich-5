# WP7a-r1 parity NB1. A #trigger body fired by this script's own #parse runs inside this script's
# row (ParseTriggers on the same thread, FormMain.cs:4425-4512 R), so its `.name` launch is part of
# this run: the child sits in m_oScriptListNew after this script and both are listed at the end of
# this run, this script first (ClassCommand_RunScript + AddScripts, FormMain.cs:4691-4699,
# 3809-3835 R) -- never the child alone first.
put #trigger {^GOKID$} {._t168_kid}
put #parse GOKID
echo a-after $scriptlist
pause 0.1
echo a-list1 $scriptlist
pause 0.3
echo a-list2 $scriptlist
