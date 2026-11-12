# WP8 N21/G56: the $-args bound to Eval's result list (gosub caller, matchwait capture, Command's own
# Eval for #eval/#if); G57 if cut at the first " then"; while gets its whole argument.
eval q matchre("c d", "(\w) (\w)")
gosub SUB x y
echo B1 [$1] [$2]
gosub SUB2 p q
if matchre("a b", "(\w) (\w)") then put #var c #eval 1 = 1
put #if {2 = 2} {#var d 1}
echo C [$1] [$2] $c $d
var t 0 then (1)
if %t then echo NOT-CUT
var u 1 then 0
if %u then echo CUT
var n 5
while %n > do echo NO
while %n do echo YES
eval
evalmath
echo done
if matchre("a", "(a)") then echo X [$1]
matchre M (\w+) here
matchwait 2
M:
echo M1 [$1]
if 1 = 1 then echo M2 [$1]
echo M3 [$1]
exit
SUB:
echo S0 [$1] [$2]
eval z 1
echo S1 [$1] [$2]
return
SUB2:
if matchre("a", "(z)") then echo no
if 1 = 1 then echo S [$1] [$2]
return
