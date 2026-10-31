var foe goblin
var move_OK ^You go (\w+)
put #var myglob zzz
action echo SAW $1 when ^The %foe (\w+)
action echo MOVED $1 when %move_OK
action echo GLOBAL when ^gl $myglob
action var x 1 when ^The %foe snarls
action remove ^The %foe snarls
action echo ARG [$1] when ^arg $1
var foe orc
put look
pause 1
echo x=%x
