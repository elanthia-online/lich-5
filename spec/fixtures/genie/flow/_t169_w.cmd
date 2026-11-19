counter set 0
loop:
counter add 1
pause 0.1
echo w-tick %c
if %c < 6 then goto loop
