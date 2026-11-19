var tongs.adj 0
action var tool tongs;put #parse @%tool when TURN it with the tongs
action var last.tool $1 when ^@(\S+)
send analyze my tongs
waitforre ^(These tongs are used|This tool is used to shovel)
if "$1" = "This tool is used to shovel" then var tongs.adj 1
else var tongs.adj 0
echo adj=%tongs.adj
send pound
waitfor Roundtime
echo tool=%tool last=%last.tool
