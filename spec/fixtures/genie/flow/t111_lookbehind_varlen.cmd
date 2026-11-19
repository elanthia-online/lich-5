var undead4 spirit|(?<!arisen \S+ )zombie(?!\s)|zombie (head-splitter|mauler)
var critters goblin|%undead4
action (point) echo POINT $1 when (%critters) attempting to stealthily advance upon you
echo registered
waitfor done
echo end
