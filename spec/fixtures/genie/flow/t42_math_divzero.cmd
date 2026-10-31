# Remix vs upstream Utility.MathCalc "divide" (Utility.cs:925-929 R guards dNumber != 0).
var x 10
math x divide 0
echo x=%x
put #var gx 10
put #math gx divide 0
echo gx=$gx
evalmath y 10 / 0
echo y=%y
