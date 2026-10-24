var a 1
action if (%a = 1) then echo yes $1;if (%a = 2) then echo no;IF (%a = 1) then echo upper;if (%a = 1) then goto lbl;echo skipped when ^go (\w+)
waitfor never
lbl:
echo at-lbl %lastlabel
