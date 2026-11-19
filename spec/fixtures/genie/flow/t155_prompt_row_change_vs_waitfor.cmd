# G32 / WP3b-r2 parity P1: the waitfor matches on the packet's first row; the prompt row's $roundtime change
# then fires the eval action goto; Remix resumes at the end of the packet, so the goto wins, and the resume
# waits for the roundtime (Script.cs:1505-1511, 1551, 2098-2104 R; Game.cs:2366-2389 R).
action goto P when eval $roundtime > 0
put swing
waitfor You swing
echo waitfor-won
exit
P:
echo prompt-change-won $roundtime
