var a swordof truth
echo A:%a
var b xyz
echo B:%b|
action setvariable cap $1 when ^CAP (.*)$
action put #var g2 $1 when ^GLOB (.*)$
put #var g1 qrs
echo D:$g1
echo H:%1|%2|%3
echo J:%2 $g1
waitfor DONE
echo K:%cap|%a
echo M:%cap
echo N:$g2
echo O:$g2 %a
put #echo P:$g1 %cap
put #echo Q:$g2
