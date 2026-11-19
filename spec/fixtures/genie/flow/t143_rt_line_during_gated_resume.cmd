# G07 (WP4 stop-gap residue s1): the waitfor resume is RT-gated, so "Early line" arrives while the script
# still waits (it is offered there and matches nothing); the matchwait armed after the resume sees only
# "Late line" (Script.cs:1505-1511 R).
put swing
waitfor You swing
send look
echo after-send
matchre got ^Early
matchre got2 ^Late
matchwait
got:
echo got-early
exit
got2:
echo got-late
