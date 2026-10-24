action echo parsed-a when ^pa$
action echo parsed-b when ^pb$
pause 0.1
put #var gx {a;b}
echo gx=$gx
put #parse pa;#var zz 1;#parse pb
echo zz=$zz
put #var flagready 1
put #var flagready 0;put #class alertstart off;put #class alertend off
echo fr=$flagready
put #echo hi;look
put look;#var q 1
echo q=$q
put a;;b
put ;c
put x;  y ;z
echo done
