# WPF: Game.SendText's cMyCommandChar gate (Game.cs:467, 527, 545 R; '/' by default, the tester's
# settings.cfg too): a '/' text is echoed but never sent and never sets $lastcommand/$lastinput;
# trigger-on-input still parses it (FormMain.cs:4391-4422 R). Corpus: `put /spelltimer` (8 tester
# files), uber `/sort`, `/track clear`, uberwatch `/restart`.
put #trigger {^/spell} {#echo trig saw $0}
put /sort name
echo lc=$lastcommand
put look
echo lc=$lastcommand
put /spelltimer
echo lc=$lastcommand
send /queued
put  /spaced
echo lc=$lastcommand
pause 0.5
echo lc=$lastcommand li=$lastinput
exit
