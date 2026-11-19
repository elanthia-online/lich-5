action echo full=[$0] g1=$1 when ^(\w+) attacks
action var who $1;put #var lastwho $1 when ^(\w+) waves
put look
pause 1
echo who=%who lastwho=$lastwho
