# G32 / WP3b-r2 parity P1: the waitfor matches on the first row of a packet, the packet's next row
# changes $health and fires the eval action goto; Remix resumes at the end of the packet, so the goto wins
# (Script.cs:1551, 2098-2104 R).
action goto HURT when eval $health < 60
waitfor ZZEND
echo end
exit
HURT:
echo hurt $health
