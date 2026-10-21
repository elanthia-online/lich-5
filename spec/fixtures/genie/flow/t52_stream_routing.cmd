loop:
matchre talk TALKTOK
matchre spell SPELLTOK
matchre room ROOMTOK
matchre done DONETOK
matchwait 5
echo timeout
exit
talk:
echo got-talk
goto loop
spell:
echo got-spell
goto loop
room:
echo got-room
goto loop
done:
echo done
