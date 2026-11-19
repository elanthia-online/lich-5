# Utility.MathCalc (Utility.cs:883-955 R) via `math`, `counter` and `#math`:
# divide skips a zero divisor (Utility.cs:928 R); the arg is clamped to >= 0 first (Utility.cs:887-890 R),
# so a negative or non-numeric arg (StringToDouble -> -1) is a 0 divisor too. mod is C# double % (Utility.cs:932-946 R):
# x % 0 = NaN, unless the value is 0 (then 0).
var a 10
math a divide -5
echo D1 a=%a
var b 10
math b divide abc
echo D2 b=%b
var c 7
math c mod 0
echo M0 c=%c
var d 7
math d mod -5
echo M1 d=%d
var e 7
math e mod abc
echo M2 e=%e
var f 0
math f mod 0
echo M3 f=%f
var g -7
math g mod 0
echo M4 g=%g
math g add 1
echo M5 g=%g
var h 7
math h mod 100000000000
echo M6 h=%h
var i -7.5
math i mod 2
echo M7 i=%i
var k -95
math k mod 96479729228174488169059713024
echo M8 k=%k
counter set 9
counter mod 0
echo C1 c=%c
counter set 9
counter divide 0
echo C2 c=%c
put #var gm 9
put #math gm mod 0
echo G1 gm=$gm
put #var gd 9
put #math gd divide -3
echo G2 gd=$gd
var j 10
math j divide 4
echo D3 j=%j
echo done
