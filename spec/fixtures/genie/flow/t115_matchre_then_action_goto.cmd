action goto ALBL when ^two
matchre MLBL ^one
put look
matchwait 5
echo timeout
exit
MLBL:
echo at-mlbl
put mlbl-send
pause 0.5
echo mlbl-done
exit
ALBL:
echo at-albl
