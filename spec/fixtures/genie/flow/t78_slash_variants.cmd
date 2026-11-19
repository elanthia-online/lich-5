put look
matchre one ORC/i
matchwait 2
echo none1
exit
one:
echo one [$0]
waitforre TROLL/i
echo two [$0]
action echo three $1 when /^an? (\w+) dies/i
action echo four $1 when /^the (\w+) falls/
action remove /^the (\w+) falls/i
waitfor done
echo end
