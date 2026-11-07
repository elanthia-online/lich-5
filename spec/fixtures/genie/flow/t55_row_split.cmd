loop:
matchre joined lies to the west\.\s+You also see
matchre own ^\s*You also see the stairway
matchre whole ^PRE MID POST$
matchre pre ^PRE\s*$
matchre done DONETOK
matchwait 5
echo timeout
exit
joined:
echo joined
goto loop
own:
echo own-line
goto loop
whole:
echo whole:$0
goto loop
pre:
echo pre:$0
goto loop
done:
echo done
