# WP5 (G64): array element indices use int.TryParse (Script.cs:2391, Globals.cs:269 R): a
# sign is allowed, an Int32 overflow is not an index (falls through to the prefix match).
var b a|b|c
#var gb x|y|z
put #var gb x|y|z
echo l=[%b(+1)] [%b(-0)] [%b(01)] [%b(3)] [%b(-1)] [%b(2147483648)] [%b(99999999999)] [%b(1x)]
echo g=[$gb(+1)] [$gb(-0)] [$gb(3)] [$gb(2147483648)] [$gb(1x)]
