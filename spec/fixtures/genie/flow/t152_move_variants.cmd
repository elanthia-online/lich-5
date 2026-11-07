# G08: move = send, then resume on the next room-desc component (TriggerMove, Game.cs:1763-1765 R); an
# empty move and nextroom are no-ops (EvalMove, Script.cs:3447-3458 R); the resume is RT-gated.
action echo act-$1 when ^You also see (.*)\.
put go
move
echo after-empty-move
nextroom
echo after-nextroom
move north
echo after-move
move south
echo after-move-rt
