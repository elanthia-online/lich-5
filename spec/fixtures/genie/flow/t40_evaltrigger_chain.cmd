# Remix vs upstream: an eval #trigger whose action changes a variable watched by a second eval
# #trigger. Upstream TriggerVariableChanged returns at depth > 1 (FormMain.cs:4677 U), so the second
# trigger never fires; Remix deleted that guard (FormMain.cs:4725 R) and it fires.
put #trigger {e/$ta = 1/} {#var tb 1}
put #trigger {e/$tb = 1/} {#echo tb-fired}
put #var ta 1
pause 0.2
echo tb=$tb
