put ._t83_b
put #trigger {^X} {#echo T1;#if {matchre("a","(")} {#echo T1-if};#echo T1-end}
put #trigger {^X$} {#echo T2}
action echo A-X when ^X$
pause 0.1
put #parse X
pause 0.1
echo after
