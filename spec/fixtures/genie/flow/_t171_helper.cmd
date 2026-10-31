waitfor knock
echo helper-saw-knock
matchre GOT ^peer bell
matchwait 3
echo helper-timeout
exit
GOT:
echo helper-got $0
waitfor typed
echo helper-saw-typed
