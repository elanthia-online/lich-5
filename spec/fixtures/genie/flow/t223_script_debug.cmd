# WP10: #script debug|debuglevel (Command.cs:2229-2238 R -> FormMain.Command_ScriptDebugLevel 6083 R).
pause 0.1
put #script debug 10 p13
var x 1
goto next
next:
put #script debuglevel 0 all
var y 2
put #script debug 10.6 nobody
var z 3
put #script debug 10 ALL
echo done
