var n 0
put ._d3_pong
action math n add 1;put #parse PONG when ^PING
pause 0.2
put #parse PING
pause 2
echo a-done %n
