# WP9 G58: do {cmd} {extra} adds extra to the repeat pattern; do clear empties the match list;
# an invalid regex is "Invalid RegExp in Do" (Script.cs:2718-2727, 3477-3517 R).
do {look} {^Try again}
matchwait 1
do 2 peer
do clear
echo after
do [bad
echo notreached
