echo A0 [$1] [$2]
if matchre("a b", "(\w) (\w)") then echo X [$1] [$2]
echo A1 [$1] [$2]
if 1 = 1 then echo Y [$1] [$2]
echo A2 [$1] [$2]
eval q matchre("c d", "(\w) (\w)")
echo A3 [$1] [$2]
eval q 1 + 1
echo A4 [$1] [$2]
put look
matchre M (\w+) here
matchwait 2
M:
echo M1 [$1]
if 1 = 1 then echo M2 [$1]
echo M3 [$1]
gosub SUB x y
echo B1 [$1] [$2]
exit
SUB:
echo S0 [$1] [$2]
if matchre("e f", "(\w) (\w)") then echo S1 [$1]
if 2 = 2 then echo S2 [$1]
echo S3 [$1] [$2]
return
