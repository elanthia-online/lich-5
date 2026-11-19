# WP9 G36: an invalid math expression errors out, and DoMath still sets the variable to 0
# (Script.cs:3293-3333 R).
var c 5
math c bogus 1
echo c=%c after
exit
scripterror:
echo se c=%c err=%lastscripterror
counter add 2
echo c=%c
