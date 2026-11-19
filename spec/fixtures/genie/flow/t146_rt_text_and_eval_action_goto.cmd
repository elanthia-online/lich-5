# G07: a text action goto and an eval action goto during roundtime both resume when it ends
# (actionwait is gated, Script.cs:1505-1511 R; WP3b-r1 parity probe q07).
action goto TXT when ^GOTEXT
action goto EVL when eval $g = 1
waitfor NEVERX
TXT:
echo txt
waitfor NEVERY
EVL:
echo evl
