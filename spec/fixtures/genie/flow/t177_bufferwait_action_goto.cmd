action goto ACT when ^ping
put ._t177_ping
matchre MW ^ping
matchwait
MW:
echo mw-resumed
exit
ACT:
echo act-goto
pause 0.5
echo after-pause
exit
