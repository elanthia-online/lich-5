var movement _t76_mover
matchre MOVE.SCRIPT.DONE ^MOVE SUCCESSFUL
matchre MOVE.FAILED ^MOVE FAILED
put .%movement
matchwait

MOVE.SCRIPT.DONE:
echo move done
exit
MOVE.FAILED:
echo move failed
