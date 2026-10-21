action put #var act1 1|#var act2 2 when ^Act now
put #var a 1|#var b 2
echo a=$a b=$b
put x;y
put p|q
put #var c {m|n}
echo c=$c
waitfor Act now
echo act1=$act1 act2=$act2
