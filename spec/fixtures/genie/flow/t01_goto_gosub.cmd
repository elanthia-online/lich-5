# goto / gosub / return / arguments
echo start %1
gosub sub one two
echo back %0
goto skip
echo NOT REACHED
skip:
echo after skip
put look
exit
sub:
echo in sub $1 $2 $0
return
