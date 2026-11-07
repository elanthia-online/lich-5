# Remix vs upstream: upstream Script.SendText (Script.cs:4385-4416 U) kills a script that sends
# 30 commands (any text) within 10 s; Remix (Script.cs:4438-4441 R) has no such check.
start:
counter add 1
put glance %c
pause 0.1
if %c < 35 then goto start
echo done %c
