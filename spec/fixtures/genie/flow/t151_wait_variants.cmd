# G08: wait = a prompt seen since the wait began AND its time (default 1 s, Utility.EvalDoubleTime) elapsed
# AND no roundtime (Script.cs:1537-1548, 3381-3393 R; Utility.cs:707-725 R).
put one
wait 2
echo w2
put two
wait 0
echo w0
put three
pause 0.5
wait
echo w-after-second-prompt
put four
wait
echo w-rt
