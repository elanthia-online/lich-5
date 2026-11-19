put #var foo bar
echo foo=$foo
put #trigger {^The bell rings} {#var rung yes}
put #class ringer on
put ring bell
waitfor The bell rings
pause 0.5
echo rung=$rung
put #tvar tmp 42
echo tmp=$tmp
