# WP9 G58: %x = a = b replaces every " = " (Script.cs:3823-3826 R); unvar removes the first word
# only (Script.cs:3546-3552 R); math with no variable does nothing (Script.cs:3281-3285 R).
%x = a = b
echo x=%x
var y 1
var z 2
unvar y z
echo y=%y z=%z
math
echo done
