loop:
matchre thought THOUGHTTOK
matchre plain PLAINTOK
matchre done DONETOK
matchwait 5
echo timeout
exit
thought:
echo got-thought
goto loop
plain:
echo got-plain
goto loop
done:
echo done
