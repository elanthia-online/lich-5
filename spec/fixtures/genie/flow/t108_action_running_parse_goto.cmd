action put #parse INNER;echo after-inner when ^OUTER
action goto lbl when ^INNER
pause 0.1
put #parse OUTER
echo row-after-parse
pause 0.2
echo not-here
exit
lbl:
echo at-lbl
