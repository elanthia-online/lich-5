waitfor
echo empty-waitfor-noop
put look
waitforre /^you (\w+)/i
echo re1 [$1] [$0]
waitforre ^Pad (\w+)$
echo pad [$1]
waitfor  spaced
echo got-spaced
match lbl  bar
matchwait 1
echo match-timeout
exit
lbl:
echo got-bar
