action goto escaped when ^You escape
put flee
match stuck You are stuck
matchwait
stuck:
echo stuck-label
exit
escaped:
echo escaped-label %lastlabel
exit
