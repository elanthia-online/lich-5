# WP8 (literal Eval.cs / MathEval.cs) through the real Script.cs / Command.cs paths.
var x 1
eval r %xx = 1
echo r1=%r
eval r (3 + 5) = 10
echo r2=%r
put #var k #evalmath 1+1 = 2
put #var j #eval 1+1 = 2
echo k=$k j=$j
var t 0 then (1)
if %t then echo G57-NOT-CUT
var n 5
while %n > do echo W-NO-DO-CUT
evalmath m 1+1 = 2
echo m=%m
evalmath m2 3!!
echo m2=%m2
evalmath z 2 & 3
echo z=%z
if {(1 = 1) && (2 = 2)} then echo BRACE
if len("abc" = 3 then echo UNCLOSED
if !"abc" then echo NEG-STRING-TRUE
eval s contains("a")
echo s=[%s]
eval u defined(x)
echo u=%u
eval v 09 && 1
echo v=%v
put #var k #evalmath (1 +
put #var k2 #eval substr("x",5,3)
put #if {substr("x",5,3)} {#var k3 1} {#var k3 2}
put #var k4 #evalmath 1+1 = 2
echo k=$k k2=$k2 k3=$k3 k4=$k4 end
