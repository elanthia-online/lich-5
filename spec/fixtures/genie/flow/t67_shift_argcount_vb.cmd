# WP1 G14: shift converts %argcount with VB Conversions.ToInteger (Script.cs:3005 R): &H hex, thousands separators, parentheses
setvariable argcount &H2
shift
echo hex argc=%argcount 0=[%0] 1=[%1] 2=[%2] 3=[%3]
setvariable argcount 1,
shift
echo comma argc=%argcount 0=[%0] 1=[%1] 2=[%2]
setvariable argcount (1)
shift
echo paren argc=%argcount 0=[%0] 1=[%1]
