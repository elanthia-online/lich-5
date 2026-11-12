Look:
matchre CollectItem /(\w+) which looks broken/i
matchre Stop /obvious (paths|exits)/i
var retrylabel Look
send look
matchwait

CollectItem:
echo collect $1
send look
matchre CollectItem /(\w+) which looks broken/i
matchre Stop /obvious (paths|exits)/i
matchwait

Stop:
echo  **** Collected ****
exit
