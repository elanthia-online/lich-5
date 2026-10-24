# WP7b: the settings that change what reaches TriggerParse (Config.cs R): parsegameonly (only the
# main window's text, Game.cs:3065 R), showlinks (<d> as {text:cmd}, Game.cs:1366-1376 R), condensed
# (no blank-line print, no bold combat split, Game.cs:705, 2963 R) and triggeroninput off (a send is
# not parsed, FormMain.cs:4408 R).
action echo L:[$0] when ^(.*)$
put #trigger {^look$} {#echo trig-look}
put look
pause 1
