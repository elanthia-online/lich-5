action put #var {'} {206};put after-fault-row;echo action-continues when ^Fault now
put #var {'} {206};put never
echo after-top-fault
put #var ok 1;#var {'} {2};#var notset 1
echo ok=$ok notset=$notset
waitfor done
echo finished
