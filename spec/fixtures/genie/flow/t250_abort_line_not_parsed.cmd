# WPF: AbortScript prints "[Script aborted! (Run time: ...)]" (Script.cs:1143-1158 R) through
# Script_EventPrintText -> AddText only (FormMain.cs:5611-5618 R): no #trigger, no action and no
# matchwait sees it. Ours prints the same line as engine output and lets Lich print no stop notice
# (the old "--- Lich: x was killed. (...genie_abort)" line reached scripts and #triggers; 5 tester
# files wait on `^--- Lich:`). An abort-dupe relaunch and a self abort are the same AbortScript.
put #trigger {Script aborted|^--- Lich:} {#echo TRIG saw it}
action echo ACTION saw $0 when Script aborted|^--- Lich:
put ._t250_child
pause 0.2
put #script abort _t250_child
pause 0.2
put ._t250_child
pause 0.2
put ._t250_child
pause 0.2
matchre seen Script aborted|^--- Lich:
put #script abort _t250_child
matchwait 0.5
echo not seen
exit
seen:
echo SEEN
