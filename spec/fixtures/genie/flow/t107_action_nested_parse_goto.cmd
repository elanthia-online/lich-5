action put #parse INNER;echo after-inner when ^OUTER
action goto lbl when ^INNER
action echo third when OUTER
waitfor never
echo not-here
exit
lbl:
echo at-lbl [%lastlabel]
