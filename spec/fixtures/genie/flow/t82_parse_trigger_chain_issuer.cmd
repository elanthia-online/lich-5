action echo act-Y when ^Y$
put #trigger {^X$} {#parse Y}
pause 0.1
put #parse X
echo after-parse
match got Y
matchwait 0.5
echo timeout
exit
got:
echo buffered-Y
