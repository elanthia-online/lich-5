action put #script pause t85_parse_paused_owner;put #parse Y;echo A-X-end when ^X$
action echo A-Y when ^Y$
put #trigger {^Y$} {#echo T-Y}
put #trigger {^RES$} {#script resume t85_parse_paused_owner}
pause 1
echo end
