action echo NEG $1 when ((?<!arisen \S+ )zombie\b|spirit)
action echo POS $1 $2 when (?<=\bthe \w+ )(orc|troll) (\w+)
action echo MID $0 when ^You see (?<!big )(?<=\w+ )wolf
put look
matchre GOTIT (?<=red \w+ )(gem|stone)
matchwait 2
echo matchwait-timeout
exit
GOTIT:
echo got $1
waitforre (?<!no \w+ )go(\w*)
echo waited $1
