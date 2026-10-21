# WPF (N13): Remix does NOT strip the showroomid " (12345)" suffix from the room-title line before
# triggers/matches (Game.cs:2822-2830, 3062-3069 R; upstream Genie4's a6f0736 strip is not in Remix):
# a `^\[Room\]$` pattern fails when the id is appended (the tester has showroomid on), natively too.
matchre bare ^\[Shard, Garden Crescent\]$
matchre suffix ^\[Shard, Garden Crescent\] \(2010671\)$
matchwait 2
echo timeout
exit
bare:
echo bare
exit
suffix:
echo suffix
exit
