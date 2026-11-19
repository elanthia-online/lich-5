action goto jumped when ^JUMP
put #parse JUMP
echo first-run-not-listed
pause 0.1
put #parse JUMP
echo not-reached
exit
jumped:
echo jumped
