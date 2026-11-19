# WP9 G36: a match on an unknown label is a script error with no row (Script.cs:1626-1631 R).
match nolabel hello
matchwait 5
echo after
exit
scripterror:
echo se %lastscripterror
