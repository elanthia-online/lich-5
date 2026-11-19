# WP9 G58: do queues the command (held while webbed/stunned) and a matchwait that sees
# $repeatregex sends it again (EvalDo / RepeatDoCommand, Script.cs:3477-3531 R).
match got You see
do look
matchwait 10
echo timeout
exit
got:
echo got %lastlabel
