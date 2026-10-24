action echo before;gosub sub;echo after when ^go
action echo later when g
waitfor done
echo not-reached
exit
sub:
echo in-sub
return
