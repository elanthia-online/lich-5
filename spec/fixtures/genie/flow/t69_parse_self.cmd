pause 0.5
put #var pv three
put #trigger {^GLOB (\w+)} {#echo trig $1}
action echo act $1 when ^PING (\w+)
put #parse PING one
match bad PING
matchwait 1
echo no-self-buffer
put #parse GLOB $dbl
put #parse
echo end
exit
bad:
echo BUFFERED
