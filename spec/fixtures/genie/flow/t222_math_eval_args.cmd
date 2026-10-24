# WP10 G68: #eval/#evalmath/#math take ArrayToString of their args (Command.cs:1017-1065 R).
put #var a #evalmath {1 + 2}
put #var b #evalmath  3   *   4
put #var c #eval "x" = "x"
put #var d #eval {"a  b" = "a  b"}
put #var n 5
put #math n add {2}
put #math n multiply 3 extra
put #math n
put #math nn add 1
put #var z abc
put #math z add 2
put #math z divide 0
put #math z bogus 2
echo a=$a b=$b c=$c d=$d n=$n nn=$nn z=$z
