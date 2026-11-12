var stepwait 0
var depth 2
var verbose 0
var color #FFFF00
var step_OK ^Obvious (paths|exits)|^It is far too dark|The gate appears to be shut, but a porter waves you through,|^You glide easily across the|^Your? peer into the gloom and see\.\.\.$
var step_FAIL ^You cannot wade in that direction\.$|^You can't go there\.$|^A gust of wind pushes you back to the|^Which way was that\?|^There is nothing like that here\.|^You can't creep in that direction|^You can't steer your.+(cart|sled) in that direction|^You can't drive that way\.$
var step_RETRY ^\.\.\.wait|^Sorry, |^The load you carry|^You stumble over a loose stone and lose your footing|^You are still dazed|^You're still catching your breath from|^The gravel shifts under your boots and you slide back down the bank instead\!|^You're not certain you can
var step_WAIT ^As you step onto the loose sand, it slides away and you tumble down the dune!$|^You try, but the passage is far too narrow for that\.$|^Crouching low, you squeeze into a gap in the wall\.$|^You keep climbing|^You begin climbing|^You should keep your mind on the walk|^You step onto a long ramp|^You step onto some steps, starting upward\.$|^You start the long walk across the causeway\.$|^Crouching low, you squeeze into a gap in the wall\.$|^After climbing the ladder for a good while|^You clamber up and over the ledge\.$
var step_END_DELAY ^You reach|you reach\.\.\.$|^At last the causeway ends|^After what feels like an age, you squeeze out of the gap into
action (step) if (%stepwait = 0) then shift;if (%stepwait = 0) then math depth subtract 1;if ((%verbose) && (len("%2") > 0)) then put #echo %color Next step: %2 when %step_OK
action (walker) goto STEP.FAILED when %step_FAIL
action (walker) goto STEP.RETRY when %step_RETRY|%step_WEB|^You can't climb that\.$
action (walker) var stepwait 1;goto STEP.WAIT when %step_WAIT
action (walker) var stepwait 0 when %step_END_DELAY
echo start 1=%1 2=%2
put %1
MAIN:
pause 0.3
echo tick depth=%depth 1=%1 stepwait=%stepwait
if %depth > 0 then goto MAIN
exit
STEP.FAILED:
echo failed
goto MAIN
STEP.RETRY:
echo retry
goto MAIN
STEP.WAIT:
echo wait-label stepwait=%stepwait
goto MAIN
