action put #parse HIT second when ^HIT first
matchre m ^HIT (\w+)
matchwait 1
echo timeout
exit
m:
echo m=$1
