put #trigger {^look$} {#echo trig-look}
put #trigger {^smile$} {#echo trig-smile}
put #trigger {^bow$} {#echo trig-bow}
put #trigger {^nod$} {#send bow}
action put smile when ^GAMEHELLO
action echo own-act:$0 when ^(look|smile|bow|nod)
put ._t180_wl
send 1 look
pause 2
put nod
pause 3
echo done
