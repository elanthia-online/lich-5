echo Genie engine prototype starting (script: %scriptname)
setvariable greeting Hello
echo %greeting from the Genie engine
counter set 0
loop:
counter add 1
echo iteration %c of 3
if %c >= 3 then goto done
pause 1
goto loop
done:
evalmath doubled %c * 2
echo doubled is %doubled
eval isdone %c >= 3
echo isdone flag is %isdone
exit
