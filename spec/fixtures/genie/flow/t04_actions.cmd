action put kick $1 when ^(\w+) attacks you
action (grp) echo grp-fired $0 when ^bang
action var hits $1 when ^You hit (\d+) times
put look
pause 1
echo hits=%hits
action (grp) off
pause 1
echo after-off
action (grp) on
pause 1
echo done
