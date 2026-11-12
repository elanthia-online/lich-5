echo waiter ready
waitfor Custom event
echo waiter-got-waitfor
match GOTIT GOTIT
matchwait 2
echo waiter-timeout
exit
GOTIT:
echo waiter-got-match
