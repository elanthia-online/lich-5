var n 0
loop:
action math hits add 1 when ^hit
action echo ONE when ^dup
action echo TWO when ^dup
math n add 1
if %n < 3 then goto loop
put look
pause 1
echo hits=%hits
