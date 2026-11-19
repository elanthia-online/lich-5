# WP3b (G11): waiteval exact Remix semantics. EvalWaitEval (Script.cs:3439-3445 R) only arms the wait;
# it resumes when a TriggerVariableChanged names a variable CONTAINED in its text and the evaluated text
# is non-empty and not "0" (Script.cs:1407-1424, 1573-1583 R). So an already-true condition waits for
# the next change (after-g at VAR g 1, not at the first line), a non-notifying set (random) never
# resumes it, game text alone never does, a global $r does not match %r, and a game variable change
# ($health) does.
action var x 1 when ^SETX
action random r 5 9 when ^RAND
put #var g 1
pause 0.1
echo waiting-g
waiteval $g = 1
echo after-g
waiteval %x = 1
echo after-x
waiteval ($health > 60)
echo after-health $health
waiteval %r > 0
echo after-r
