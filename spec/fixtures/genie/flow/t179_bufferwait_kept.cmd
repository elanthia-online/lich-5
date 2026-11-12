action goto ACT when ^ping
put ._t179_h
matchre MW ^ping
matchwait
MW:
echo mw
exit
ACT:
echo act
waitfor ZZZ
echo got-zzz
exit
