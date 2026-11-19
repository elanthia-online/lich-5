# WPF: a runtime `#config mycommandchar` (Config.cs:638-645 R) moves the gate (Game.cs:545 R):
# the new char is held back, '/' is a game command again.
put #config mycommandchar !
put !held
echo lc=$lastcommand
put /sent
echo lc=$lastcommand
put #config mycommandchar
put !still held
echo lc=$lastcommand
exit
