if ("%1" = "my") then goto Shift

BagCheck:
if matchre ("%0" , "(.*) cs$") then goto CanvasSack
if matchre ("%0" , "(.*) pouch$|(.*) pou$") then goto Pouch
send put my %0 in my $backpack
exit

Shift:
shift
goto BagCheck

CanvasSack:
if_3 then
{
send put my %1 %2 in my canvas sack
exit
}
send put my %1 in my canvas sack
exit

Pouch:
if_3 then
{
send put my %1 %2 in my tester's pouch
exit
}
send put my %1 in my tester's pouch
exit