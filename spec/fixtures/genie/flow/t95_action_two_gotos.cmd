action echo a-before;goto first;echo a-after when ^go
action echo b-before;goto second;echo b-after when go
action echo c-after-gotos when o$
waitfor never
first:
echo at-first %lastlabel
exit
second:
echo at-second %lastlabel
exit
