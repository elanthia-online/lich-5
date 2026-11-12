# WP9: debug N prints PrintDebug lines to the main window (Script.cs:4388-4426 R) and Eval's
# unassigned-variable warning is a PrintError (Script.cs:1324-1356 R).
debug 5
var x 1
if %x = 1 then echo yes
if %nope = 1 then echo no
action echo act when ^boom
gosub sub
pause 0.1
math x add 1
eval y 1+1
evalmath z 2*3
counter add 2
unvar y
match lbl boom
matchwait 2
lbl:
echo err=%lastscripterror
exit
sub:
goto sub2
sub2:
return
