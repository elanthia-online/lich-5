put #var probe 42
put #var k1 a b  c
echo k1=[$k1]
put #var k2 "quoted value"
echo k2=[$k2]
put #var k3 .dot;x
echo k3=[$k3]
put #tvar k4 {x;y;z}
echo k4=[$k4]
put #var k5 \$probe
echo k5=[$k5]
put #var k6 #evalmath 1+2
echo k6=[$k6]
put #var k7 {first;._t137_helper}
echo k7=[$k7]
put #var k8 {one;#var inner 9}
echo k8=[$k8] inner=$inner
put #var k9 {-1 queued}
echo k9=[$k9]
put #svar k10 {p;q}
echo k10=[$k10]
pause 2
echo done
