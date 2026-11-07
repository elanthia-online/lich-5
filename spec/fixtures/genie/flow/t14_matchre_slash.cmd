put look
matchre lower /the (\w+) DIES/i
matchre plain /^A (\w+) falls\.$/
matchwait 5
echo none
exit
lower:
echo lower $1
put look2
matchre plain /^A (\w+) falls\.$/
matchwait 5
echo none2
exit
plain:
echo plain $1
