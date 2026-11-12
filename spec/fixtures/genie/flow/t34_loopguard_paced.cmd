start:
put look
pause 0.5
counter add 1
if %c < 15 then goto start
echo done %c
