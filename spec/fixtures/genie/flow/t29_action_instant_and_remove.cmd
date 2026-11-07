action instant put inst $1 when ^ping (\w+)
action put norm $1 when ^pong (\w+)
put look
pause 1
action remove ^pong (\w+)
pause 1
echo end
