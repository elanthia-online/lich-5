action instant (cA) echo iA $1 when ^ping (\w+)
action (cB) instant echo iB $1 when ^ping (\w+)z?
action (cC) add echo iC when ^ping (\w+)y?
action  (cD) echo iD when ^ping (\w+)x?
action add (cE) echo iE when ^ping (\w+)w?
action (cA) off
put look
pause 1
action (cA) on
pause 1
