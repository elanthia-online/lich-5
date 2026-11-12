echo child-start %1 %0 %scriptname
put #var t159 set-by-child
put #script abort all except nobody
echo child-survived
pause 0.2
echo child-later $scriptlist
