# WP10 G67: #event (Command.cs:1103-1132 R; Events.cs R): absolute due times, one per tick, listing.
put #event 1 #echo ev1
put #event 0.5 #echo ev05
put #event x #echo evbad
put #event 2 {#var e2 done;#echo ev2}
put #event 0.5 #echo ev05b
put #event
put #events ev0
put #event 3
pause 1.7
echo mid
put #event 9 #echo gone
put #event clear
put #event
pause 0.5
echo e2=$e2
