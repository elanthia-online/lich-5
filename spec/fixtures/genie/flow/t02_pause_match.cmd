echo begin
pause 2
echo after pause
put look
match seen You see
match nothing nothing here
matchwait 5
echo TIMEOUT
put timedout
matchre caught /^The (\w+) (\w+)\.$/
matchwait
seen:
echo seen label
exit
nothing:
echo nothing label
exit
caught:
echo caught $1 $2 [$0]
exit
