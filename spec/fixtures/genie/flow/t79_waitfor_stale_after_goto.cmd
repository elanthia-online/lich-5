action goto x when ^go$
waitforre ^You (\w+)
echo not-here
exit
x:
match y zzz
matchwait 1
echo after [$1]
exit
y:
echo y
